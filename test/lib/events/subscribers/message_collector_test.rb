# frozen_string_literal: true

require "test_helper"

class Events::Subscribers::MessageCollectorTest < ActiveSupport::TestCase
  def setup
    @collector = Events::Subscribers::MessageCollector.new
  end

  test "emit collects user_message as role user" do
    @collector.emit({payload: {type: "user_message", content: "hello"}})

    assert_equal 1, @collector.messages.size
    assert_equal "user", @collector.messages.first[:role]
    assert_equal "hello", @collector.messages.first[:content]
  end

  test "emit collects agent_message as role assistant" do
    @collector.emit({payload: {type: "agent_message", content: "reply"}})

    assert_equal "assistant", @collector.messages.first[:role]
    assert_equal "reply", @collector.messages.first[:content]
  end

  test "emit ignores system_message" do
    @collector.emit({payload: {type: "system_message", content: "boot"}})
    assert_empty @collector.messages
  end

  test "emit ignores tool_call" do
    @collector.emit({payload: {type: "tool_call", content: "running"}})
    assert_empty @collector.messages
  end

  test "emit ignores tool_response" do
    @collector.emit({payload: {type: "tool_response", content: "done"}})
    assert_empty @collector.messages
  end

  test "emit ignores events with nil content" do
    @collector.emit({payload: {type: "user_message", content: nil}})
    assert_empty @collector.messages
  end

  test "messages returns a copy — mutations do not affect internal state" do
    @collector.emit({payload: {type: "user_message", content: "hello"}})
    copy = @collector.messages
    copy.clear

    assert_equal 1, @collector.messages.size
  end

  test "messages_push adds pre-built messages directly" do
    @collector.messages_push({role: "user", content: "loaded from db"})

    assert_equal 1, @collector.messages.size
    assert_equal "loaded from db", @collector.messages.first[:content]
  end

  test "clear empties all collected messages" do
    @collector.emit({payload: {type: "user_message", content: "hi"}})
    @collector.clear

    assert_empty @collector.messages
  end

  test "collects multiple messages in order" do
    @collector.emit({payload: {type: "user_message", content: "first"}})
    @collector.emit({payload: {type: "agent_message", content: "second"}})
    @collector.emit({payload: {type: "user_message", content: "third"}})

    messages = @collector.messages
    assert_equal 3, messages.size
    assert_equal "first", messages[0][:content]
    assert_equal "second", messages[1][:content]
    assert_equal "third", messages[2][:content]
  end
end
