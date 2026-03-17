# frozen_string_literal: true

require "test_helper"

class Events::BaseTest < ActiveSupport::TestCase
  test "type raises NotImplementedError" do
    event = Events::Base.new(content: "hello")
    assert_raises(NotImplementedError) { event.type }
  end

  test "timestamp is set on initialization" do
    before = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
    event = Events::UserMessage.new(content: "hi")
    after = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)

    assert_operator event.timestamp, :>=, before
    assert_operator event.timestamp, :<=, after
  end

  test "content is accessible" do
    event = Events::UserMessage.new(content: "hello world")
    assert_equal "hello world", event.content
  end

  test "session_id defaults to nil" do
    event = Events::UserMessage.new(content: "hi")
    assert_nil event.session_id
  end

  test "session_id can be set" do
    event = Events::UserMessage.new(content: "hi", session_id: 42)
    assert_equal 42, event.session_id
  end

  test "event_name returns namespaced anima prefix" do
    event = Events::UserMessage.new(content: "hi")
    assert_equal "anima.user_message", event.event_name
  end

  test "to_h includes type, content, session_id, and timestamp" do
    event = Events::UserMessage.new(content: "hi", session_id: 1)
    hash = event.to_h

    assert_equal "user_message", hash[:type]
    assert_equal "hi", hash[:content]
    assert_equal 1, hash[:session_id]
    assert_kind_of Integer, hash[:timestamp]
  end

  # ─── Concrete subclasses ────────────────────────────────────────────────

  test "UserMessage has type user_message" do
    assert_equal "user_message", Events::UserMessage.new(content: "x").type
  end

  test "AgentMessage has type agent_message" do
    assert_equal "agent_message", Events::AgentMessage.new(content: "x").type
  end

  test "SystemMessage has type system_message" do
    assert_equal "system_message", Events::SystemMessage.new(content: "x").type
  end

  test "ToolCall has type tool_call" do
    assert_equal "tool_call", Events::ToolCall.new(content: "x", tool_name: "bash").type
  end

  test "ToolResponse has type tool_response" do
    assert_equal "tool_response", Events::ToolResponse.new(content: "x", tool_name: "bash").type
  end

  test "ToolResponse success? returns true by default" do
    event = Events::ToolResponse.new(content: "ok", tool_name: "bash")
    assert event.success?
  end

  test "ToolResponse success? returns false when initialized with success: false" do
    event = Events::ToolResponse.new(content: "error", tool_name: "bash", success: false)
    assert_not event.success?
  end
end
