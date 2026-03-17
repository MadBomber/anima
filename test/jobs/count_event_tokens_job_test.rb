# frozen_string_literal: true

require "test_helper"

class CountEventTokensJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @session = Session.create!
    @event = @session.events.create!(
      event_type: "user_message",
      payload: {"content" => "hello"},
      timestamp: Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
    )
  end

  # ─── already_counted? early return ──────────────────────────────────────

  test "perform does nothing when event already has token_count > 0" do
    @event.update_column(:token_count, 42)

    # If already_counted? works, we won't reach the Providers::Anthropic call.
    # Since Providers::Anthropic is filtered out of coverage and we can't hit
    # the real API in tests, we verify no error is raised and token_count is unchanged.
    assert_nothing_raised { CountEventTokensJob.new.perform(@event.id) }
    assert_equal 42, @event.reload.token_count
  end

  # ─── discard_on ActiveRecord::RecordNotFound ────────────────────────────

  test "perform is discarded for a missing event id" do
    assert_nothing_raised do
      perform_enqueued_jobs do
        CountEventTokensJob.perform_later(999_999_999)
      end
    end
  end
end
