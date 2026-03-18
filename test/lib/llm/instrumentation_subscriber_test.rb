# frozen_string_literal: true

require "test_helper"

class LLM::InstrumentationSubscriberTest < ActiveSupport::TestCase
  CHAT_EVENT = LLM::InstrumentationSubscriber::CHAT_EVENT

  def setup
    @subscriber = LLM::InstrumentationSubscriber.new
    @log_lines  = []
    @original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(StringIO.new).tap do |logger|
      logger.formatter = ->(_, _, _, msg) { @log_lines << msg; "" }
    end
  end

  def teardown
    Rails.logger = @original_logger
  end

  # ── Helper ────────────────────────────────────────────────────────────────

  def fire_event(payload, duration_ms: 100)
    event = ActiveSupport::Notifications::Event.new(
      CHAT_EVENT, Time.now, Time.now + (duration_ms / 1000.0), SecureRandom.hex(8), payload
    )
    @subscriber.call(event)
    @log_lines.last
  end

  def base_payload(overrides = {})
    {
      provider:               "anthropic",
      model:                  "claude-sonnet-4-6",
      input_tokens:           500,
      output_tokens:          100,
      cached_tokens:          0,
      cache_creation_tokens:  0,
      thinking_tokens:        0,
      streaming:              false,
      metadata:               {}
    }.merge(overrides)
  end

  # ── Core format ───────────────────────────────────────────────────────────

  test "logs model and token counts" do
    line = fire_event(base_payload)

    assert_includes line, "model=claude-sonnet-4-6"
    assert_includes line, "in=500"
    assert_includes line, "out=100"
  end

  test "includes duration in milliseconds" do
    line = fire_event(base_payload, duration_ms: 250)

    assert_includes line, "ms"
  end

  test "defaults context label to 'agent' when metadata is empty" do
    line = fire_event(base_payload)

    assert_includes line, "[LLM] agent"
  end

  # ── Metadata context ──────────────────────────────────────────────────────

  test "uses context label from metadata" do
    line = fire_event(base_payload(metadata: {context: "analytical_brain", session_id: 99}))

    assert_includes line, "[LLM] analytical_brain"
  end

  test "includes session_id when present in metadata" do
    line = fire_event(base_payload(metadata: {session_id: 42, context: "agent"}))

    assert_includes line, "session=42"
  end

  test "omits session_id tag when metadata has no session_id" do
    line = fire_event(base_payload(metadata: {}))

    refute_includes line, "session="
  end

  # ── Optional token fields ─────────────────────────────────────────────────

  test "omits cache_hit when cached_tokens is zero" do
    line = fire_event(base_payload(cached_tokens: 0))

    refute_includes line, "cache_hit"
  end

  test "includes cache_hit when cached_tokens is non-zero" do
    line = fire_event(base_payload(cached_tokens: 300))

    assert_includes line, "cache_hit=300"
  end

  test "omits cache_write when cache_creation_tokens is zero" do
    line = fire_event(base_payload(cache_creation_tokens: 0))

    refute_includes line, "cache_write"
  end

  test "includes cache_write when cache_creation_tokens is non-zero" do
    line = fire_event(base_payload(cache_creation_tokens: 150))

    assert_includes line, "cache_write=150"
  end

  test "omits think when thinking_tokens is zero" do
    line = fire_event(base_payload(thinking_tokens: 0))

    refute_includes line, "think"
  end

  test "includes think when thinking_tokens is non-zero" do
    line = fire_event(base_payload(thinking_tokens: 800))

    assert_includes line, "think=800"
  end

  # ── subscribe! wires the class into ActiveSupport::Notifications ──────────

  test "subscribe! registers the subscriber so fired events reach it" do
    subscriber = LLM::InstrumentationSubscriber.new
    log_lines  = []
    # Override logger on this subscriber's Rails.logger capture
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(StringIO.new).tap do |l|
      l.formatter = ->(_, _, _, msg) { log_lines << msg; "" }
    end

    subscription = ActiveSupport::Notifications.subscribe(CHAT_EVENT, subscriber)
    ActiveSupport::Notifications.instrument(CHAT_EVENT, base_payload(metadata: {session_id: 7}))
    ActiveSupport::Notifications.unsubscribe(subscription)

    assert log_lines.any? { |l| l.include?("session=7") },
      "expected instrumentation subscriber to log the fired event"
  ensure
    Rails.logger = original
    ActiveSupport::Notifications.unsubscribe(subscription) rescue nil
  end
end
