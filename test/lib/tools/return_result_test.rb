# frozen_string_literal: true

require "test_helper"

class Tools::ReturnResultTest < ActiveSupport::TestCase
  # Minimal subscriber that records emitted event hashes for assertions.
  class RecordingSubscriber
    include Events::Subscriber

    attr_reader :events

    def initialize
      @events = []
      @mutex = Mutex.new
    end

    def emit(event)
      @mutex.synchronize { @events << event }
    end
  end

  def setup
    @parent = Session.create!
    @child = Session.create!(parent_session: @parent)
    @child.events.create!(
      event_type: "user_message",
      payload: {"content" => "the assigned task"},
      timestamp: 1
    )
    @tool = Tools::ReturnResult.new(session: @child)
    @subscriber = RecordingSubscriber.new
    Events::Bus.subscribe(@subscriber)
  end

  def teardown
    Events::Bus.unsubscribe(@subscriber)
  end

  test "tool_name is return_result" do
    assert_equal "return_result", Tools::ReturnResult.tool_name
  end

  test "call emits tool_call event to parent session" do
    @tool.call("result" => "here is the answer")

    tool_call = @subscriber.events.find { |e| e[:name]&.include?("tool_call") }
    assert tool_call, "Expected a tool_call event to be emitted"
    assert_equal @parent.id, tool_call.dig(:payload, :session_id)
  end

  test "call emits tool_response event to parent session with the result" do
    @tool.call("result" => "finished output")

    tool_response = @subscriber.events.find { |e| e[:name]&.include?("tool_response") }
    assert tool_response, "Expected a tool_response event to be emitted"
    assert_equal @parent.id, tool_response.dig(:payload, :session_id)
    assert_equal "finished output", tool_response.dig(:payload, :content)
  end

  test "call returns confirmation message with parent session id" do
    result = @tool.call("result" => "done")

    assert_includes result, @parent.id.to_s
  end

  test "call returns error for blank result" do
    result = @tool.call("result" => "")

    assert_kind_of Hash, result
    assert_match(/blank/i, result[:error])
  end

  test "call returns error when session has no parent" do
    orphan = Session.create!
    tool = Tools::ReturnResult.new(session: orphan)
    result = tool.call("result" => "orphan result")

    assert_kind_of Hash, result
    assert_match(/no parent session/i, result[:error])
  end

  test "params_schema returns an object schema with result property" do
    schema = Tools::ReturnResult.new(session: @child).params_schema
    assert_equal "object", schema["type"]
    assert schema["properties"].key?("result")
  end
end
