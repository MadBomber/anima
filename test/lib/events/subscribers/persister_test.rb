# frozen_string_literal: true

require "test_helper"

class Events::Subscribers::PersisterTest < ActiveSupport::TestCase
  def setup
    @session = Session.create!
    @persister = Events::Subscribers::Persister.new(@session)
  end

  # ─── Session-scoped persister ────────────────────────────────────────────

  test "emit persists a user_message event to the session" do
    ts = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
    @persister.emit(payload: {type: "user_message", content: "hello", session_id: @session.id, timestamp: ts})

    assert_equal 1, @session.events.where(event_type: "user_message").count
  end

  test "emit stores the full payload on the event" do
    ts = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
    @persister.emit(payload: {type: "agent_message", content: "hi there", session_id: @session.id, timestamp: ts})

    event = @session.events.last
    assert_equal "hi there", event.payload["content"]
  end

  test "emit stores tool_use_id when present" do
    ts = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
    @persister.emit(payload: {
      type: "tool_call",
      content: "call",
      tool_name: "bash",
      tool_use_id: "toolu_abc123",
      session_id: @session.id,
      timestamp: ts
    })

    event = @session.events.last
    assert_equal "toolu_abc123", event.tool_use_id
  end

  test "emit ignores payload that is not a Hash" do
    assert_nothing_raised { @persister.emit(payload: "not a hash") }
    assert_equal 0, @session.events.count
  end

  test "emit ignores payload without type" do
    @persister.emit(payload: {content: "orphan", session_id: @session.id})
    assert_equal 0, @session.events.count
  end

  # ─── Global persister (session looked up by session_id) ──────────────────

  test "global persister routes events to the correct session" do
    other_session = Session.create!
    global = Events::Subscribers::Persister.new

    ts = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
    global.emit(payload: {type: "user_message", content: "routed", session_id: other_session.id, timestamp: ts})

    assert_equal 1, other_session.events.count
    assert_equal 0, @session.events.count
  end

  test "global persister ignores event with unknown session_id" do
    global = Events::Subscribers::Persister.new
    assert_nothing_raised do
      global.emit(payload: {type: "user_message", content: "lost", session_id: 999_999})
    end
  end

  # ─── session= setter ─────────────────────────────────────────────────────

  test "session= changes the target session for subsequent events" do
    other = Session.create!
    @persister.session = other

    ts = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
    @persister.emit(payload: {type: "agent_message", content: "rerouted", session_id: @session.id, timestamp: ts})

    assert_equal 1, other.events.count
    assert_equal 0, @session.events.count
  end
end
