# frozen_string_literal: true

require "test_helper"

class EventTest < ActiveSupport::TestCase
  def setup
    @session = Session.create!
  end

  # ─── Validations ─────────────────────────────────────────────────────────

  test "valid with all required attributes" do
    event = Event.new(session: @session, event_type: "user_message", payload: {content: "hi"}, timestamp: 1)
    assert event.valid?
  end

  test "requires event_type" do
    event = Event.new(session: @session, payload: {content: "hi"}, timestamp: 1)
    assert_not event.valid?
    assert_includes event.errors[:event_type], "can't be blank"
  end

  test "rejects unknown event_type" do
    event = Event.new(session: @session, event_type: "unknown", payload: {content: "hi"}, timestamp: 1)
    assert_not event.valid?
    assert_includes event.errors[:event_type], "is not included in the list"
  end

  test "accepts all defined event types" do
    Event::TYPES.each do |type|
      payload = case type
      when "tool_call", "tool_response" then {content: "x", tool_name: "bash"}
      else {content: "x"}
      end
      event = Event.new(session: @session, event_type: type, payload: payload, timestamp: 1)
      assert event.valid?, "Expected #{type} to be valid, got: #{event.errors.full_messages}"
    end
  end

  test "requires payload" do
    event = Event.new(session: @session, event_type: "user_message", timestamp: 1)
    event.payload = nil
    assert_not event.valid?
    assert_includes event.errors[:payload], "can't be blank"
  end

  test "requires timestamp" do
    event = Event.new(session: @session, event_type: "user_message", payload: {content: "hi"})
    event.timestamp = nil
    assert_not event.valid?
    assert_includes event.errors[:timestamp], "can't be blank"
  end

  test "requires session" do
    event = Event.new(event_type: "user_message", payload: {content: "hi"}, timestamp: 1)
    assert_not event.valid?
  end

  # ─── Roles ───────────────────────────────────────────────────────────────

  test "api_role returns user for user_message" do
    event = @session.events.create!(event_type: "user_message", payload: {content: "hi"}, timestamp: 1)
    assert_equal "user", event.api_role
  end

  test "api_role returns assistant for agent_message" do
    event = @session.events.create!(event_type: "agent_message", payload: {content: "hi"}, timestamp: 1)
    assert_equal "assistant", event.api_role
  end

  test "api_role raises KeyError for non-LLM event types" do
    event = @session.events.create!(event_type: "tool_call", payload: {content: "x", tool_name: "bash"}, timestamp: 1)
    assert_raises(KeyError) { event.api_role }
  end

  # ─── Predicates ──────────────────────────────────────────────────────────

  test "llm_message? is true for user_message and agent_message" do
    assert Event.new(event_type: "user_message").llm_message?
    assert Event.new(event_type: "agent_message").llm_message?
  end

  test "llm_message? is false for non-LLM types" do
    %w[system_message tool_call tool_response].each do |type|
      assert_not Event.new(event_type: type).llm_message?, "Expected #{type} not to be llm_message"
    end
  end

  test "context_event? is true for all context types" do
    Event::CONTEXT_TYPES.each do |type|
      assert Event.new(event_type: type).context_event?, "Expected #{type} to be context_event"
    end
  end

  test "pending? returns true when status is pending" do
    event = Event.new(event_type: "user_message", status: "pending")
    assert event.pending?
  end

  test "pending? returns false when status is nil" do
    event = Event.new(event_type: "user_message", status: nil)
    assert_not event.pending?
  end

  # ─── Scopes ──────────────────────────────────────────────────────────────

  test "llm_messages scope returns only user and agent messages" do
    @session.events.create!(event_type: "user_message", payload: {content: "hi"}, timestamp: 1)
    @session.events.create!(event_type: "agent_message", payload: {content: "hello"}, timestamp: 2)
    @session.events.create!(event_type: "system_message", payload: {content: "boot"}, timestamp: 3)

    types = Event.llm_messages.pluck(:event_type)
    assert_includes types, "user_message"
    assert_includes types, "agent_message"
    assert_not_includes types, "system_message"
  end

  test "context_events scope includes all context types" do
    @session.events.create!(event_type: "user_message", payload: {content: "hi"}, timestamp: 1)
    @session.events.create!(event_type: "system_message", payload: {content: "boot"}, timestamp: 2)
    @session.events.create!(event_type: "tool_call", payload: {content: "x", tool_name: "bash"}, timestamp: 3)

    types = @session.events.context_events.pluck(:event_type)
    assert_includes types, "user_message"
    assert_includes types, "system_message"
    assert_includes types, "tool_call"
  end

  test "pending scope returns only pending events" do
    delivered = @session.events.create!(event_type: "user_message", payload: {content: "delivered"}, timestamp: 1)
    pending = @session.events.create!(event_type: "user_message", payload: {content: "queued"}, timestamp: 2, status: "pending")

    assert_includes Event.pending, pending
    assert_not_includes Event.pending, delivered
  end

  test "deliverable scope excludes pending events" do
    delivered = @session.events.create!(event_type: "user_message", payload: {content: "delivered"}, timestamp: 1)
    @session.events.create!(event_type: "user_message", payload: {content: "queued"}, timestamp: 2, status: "pending")

    assert_includes Event.deliverable, delivered
    assert_equal 1, @session.events.deliverable.count
  end

  # ─── Token estimation ─────────────────────────────────────────────────

  test "estimate_tokens uses content byte size for message events" do
    event = @session.events.create!(
      event_type: "user_message", payload: {"content" => "hello world"}, timestamp: 1
    )
    expected = [("hello world".bytesize / 4.0).ceil, 1].max
    assert_equal expected, event.estimate_tokens
  end

  test "estimate_tokens uses full payload JSON for tool events" do
    payload = {"content" => "calling", "tool_name" => "bash", "tool_input" => {"command" => "ls"}}
    event = @session.events.create!(event_type: "tool_call", payload: payload, timestamp: 1)
    expected = [(payload.to_json.bytesize / 4.0).ceil, 1].max
    assert_equal expected, event.estimate_tokens
  end

  test "estimate_tokens returns at least 1 for empty content" do
    event = @session.events.create!(event_type: "user_message", payload: {"content" => ""}, timestamp: 1)
    assert event.estimate_tokens >= 1
  end

  test "estimate_tokens returns at least 1 for nil content" do
    event = @session.events.create!(event_type: "user_message", payload: {"content" => nil}, timestamp: 1)
    assert event.estimate_tokens >= 1
  end

end
