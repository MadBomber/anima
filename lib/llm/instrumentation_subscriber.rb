# frozen_string_literal: true

module LLM
  # Logs ActiveSupport::Notifications events emitted by ruby_llm-instrumentation.
  #
  # Subscribes to +complete_chat.ruby_llm+ and writes a single structured
  # log line per LLM completion: context, session, model, token breakdown,
  # and wall-clock duration. Session context (session_id, context label) is
  # attached via {RubyLLM::Instrumentation.with} blocks in {AgentLoop} and
  # {AnalyticalBrain::Runner}.
  #
  # @example Log output
  #   [LLM] agent session=42 model=claude-sonnet-4-6 in=1234 out=567 312ms
  #   [LLM] analytical_brain session=42 model=claude-haiku-4-5 in=456 think=89 out=123 88ms
  #   [LLM] agent session=7 model=claude-sonnet-4-6 in=800 cache_hit=400 out=210 201ms
  class InstrumentationSubscriber
    CHAT_EVENT = "complete_chat.ruby_llm"

    # Registers the subscriber with ActiveSupport::Notifications.
    # Called exactly once at boot from config/initializers/event_subscribers.rb.
    # Calling more than once would register duplicate subscriptions and double-log.
    def self.subscribe!
      ActiveSupport::Notifications.subscribe(CHAT_EVENT, new)
    end

    # Called by ActiveSupport::Notifications for each complete_chat event.
    #
    # @param event [ActiveSupport::Notifications::Event]
    def call(event)
      payload = event.payload
      meta    = payload[:metadata] || {}
      label   = meta[:context] || "agent"
      sid     = meta[:session_id]

      parts = ["[LLM] #{label}"]
      parts << "session=#{sid}" if sid
      parts << "model=#{payload[:model]}"
      parts.concat(token_parts(payload))
      parts << "#{event.duration.round(0)}ms"

      Rails.logger.info(parts.join(" "))
    end

    private

    # Builds the token breakdown, omitting zero-value optional fields.
    #
    # @param payload [Hash]
    # @return [Array<String>]
    def token_parts(payload)
      parts = ["in=#{payload[:input_tokens]}"]
      parts << "cache_hit=#{payload[:cached_tokens]}"          if payload[:cached_tokens].to_i > 0
      parts << "cache_write=#{payload[:cache_creation_tokens]}" if payload[:cache_creation_tokens].to_i > 0
      parts << "think=#{payload[:thinking_tokens]}"             if payload[:thinking_tokens].to_i > 0
      parts << "out=#{payload[:output_tokens]}"
      parts
    end
  end
end
