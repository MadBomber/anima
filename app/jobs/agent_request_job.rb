# frozen_string_literal: true

# Executes an LLM agent loop as a background job with retry logic
# for transient failures (network errors, rate limits, server errors).
#
# Emits events via {Events::Bus} as it progresses, making results visible
# to any subscriber (TUI, WebSocket clients). All retry and failure
# notifications are emitted as {Events::SystemMessage} to avoid polluting
# the LLM context window.
#
# @example Inline execution (TUI)
#   AgentRequestJob.perform_now(session.id)
#
# @example Background execution (future Brain/TUI separation)
#   AgentRequestJob.perform_later(session.id)
class AgentRequestJob < ApplicationJob
  queue_as :default

  retry_on RubyLLM::RateLimitError, RubyLLM::ServerError,
    RubyLLM::ServiceUnavailableError, RubyLLM::OverloadedError,
    wait: :polynomially_longer, attempts: 5 do |job, error|
    Events::Bus.emit(Events::SystemMessage.new(
      content: "Failed after multiple retries: #{error.message}",
      session_id: job.arguments.first
    ))
  end

  discard_on ActiveRecord::RecordNotFound
  discard_on RubyLLM::UnauthorizedError do |job, error|
    session_id = job.arguments.first
    # Persistent system message for the event log
    Events::Bus.emit(Events::SystemMessage.new(
      content: "Authentication failed: #{error.message}",
      session_id: session_id
    ))
    # Transient signal to trigger TUI token setup popup (not persisted)
    ActionCable.server.broadcast(
      "session_#{session_id}",
      {"action" => "authentication_required", "message" => error.message}
    )
  end

  # Drives the full agent loop for a session: claims the processing lock,
  # optionally runs a blocking analytical brain pass, loops the agent until
  # no pending messages remain, then schedules a post-response brain pass.
  # The ensure block always releases the lock and clears any interrupt flag
  # regardless of how the job exits.
  #
  # @param session_id [Integer] ID of the session to process
  # @return [void]
  def perform(session_id)
    session = Session.find(session_id)

    # Atomic: only one job processes a session at a time. If another job
    # is already running, this one exits — the running job will pick up
    # any pending messages after its current loop completes.
    return unless claim_processing(session_id)

    # Run analytical brain BEFORE the main agent on user messages so
    # activated skills are available for the current response.
    run_analytical_brain_blocking(session)

    agent_loop = AgentLoop.new(session: session)
    loop do
      agent_loop.run
      promoted = session.promote_pending_messages!
      break if promoted == 0
    end

    # Non-blocking analytical brain run after agent completes —
    # handles post-response updates (renaming, skill changes).
    session.schedule_analytical_brain!
  ensure
    # Each cleanup step is independent. If one raises (e.g. DB unavailable),
    # the others still run so the session lock is never permanently stuck.
    safely { release_processing(session_id) }
    safely { clear_interrupt(session_id) }
    safely { agent_loop&.finalize }
  end

  private

  # Runs the analytical brain synchronously before the main agent loop.
  # Respects the blocking_on_user_message setting and session guards
  # (skips sub-agents and sessions with too few messages).
  #
  # @param session [Session] the session being processed
  # @return [void]
  def run_analytical_brain_blocking(session)
    return unless Anima::Settings.analytical_brain_blocking_on_user_message
    return if session.sub_agent?

    AnalyticalBrain::Runner.new(session).call
  rescue => error
    # The analytical brain is best-effort: skill activation enhances the
    # response but the main agent must still reply even if it fails.
    msg = "FAILED (blocking) session=#{session.id}: #{error.class}: #{error.message}"
    Rails.logger.error("Analytical brain #{msg}")
    AnalyticalBrain.logger.error("#{msg}\n#{error.backtrace&.first(10)&.join("\n")}")
  end

  # Sets the session's processing flag atomically. Returns true if this
  # job claimed the lock, false if another job already holds it.
  # Records locked_at so a watchdog can recover from crashed processes.
  #
  # @param session_id [Integer] session to lock
  # @return [Boolean] true if this job acquired the lock
  def claim_processing(session_id)
    Session.where(id: session_id, processing: false)
      .update_all(processing: true, locked_at: Time.current) == 1
  end

  # Clears the processing flag and timestamp so the session can accept new jobs.
  #
  # @param session_id [Integer] session to unlock
  # @return [void]
  def release_processing(session_id)
    Session.where(id: session_id).update_all(processing: false, locked_at: nil)
  end

  # Safety-net clearing of the interrupt flag. The primary clear happens in
  # {LLM::Client#clear_interrupt!} after handling the interrupt; this ensures
  # the flag is reset even if the job crashes before reaching that code path.
  #
  # @param session_id [Integer] session whose interrupt flag to clear
  # @return [void]
  def clear_interrupt(session_id)
    Session.where(id: session_id, interrupt_requested: true).update_all(interrupt_requested: false)
  end

  # Runs a block and swallows any exception, logging it at error level.
  # Used in the ensure block so each cleanup step runs independently.
  #
  # @yieldreturn [void]
  # @return [void]
  def safely
    yield
  rescue => e
    Rails.logger.error("[AgentRequestJob] cleanup error: #{e.class}: #{e.message}")
  end

  # Emits a system message before each retry so the user sees
  # "retrying..." instead of nothing.
  #
  # @param options [Hash] ActiveJob retry options; uses :error and :wait keys
  # @return [void]
  def retry_job(options = {})
    error = options[:error]
    wait = options[:wait]

    Events::Bus.emit(Events::SystemMessage.new(
      content: "#{error.message} — retrying in #{wait.to_i}s...",
      session_id: arguments.first
    ))

    super
  end
end
