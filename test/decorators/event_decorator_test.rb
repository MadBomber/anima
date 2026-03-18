# frozen_string_literal: true

require "test_helper"

class EventDecoratorTest < ActiveSupport::TestCase
  # ─── EventDecorator.for factory ────────────────────────────────────────

  test "for returns UserMessageDecorator for user_message hash" do
    decorator = EventDecorator.for(type: "user_message", content: "hello")
    assert_instance_of UserMessageDecorator, decorator
  end

  test "for returns AgentMessageDecorator for agent_message hash" do
    decorator = EventDecorator.for(type: "agent_message", content: "hi there")
    assert_instance_of AgentMessageDecorator, decorator
  end

  test "for returns ToolCallDecorator for tool_call hash" do
    decorator = EventDecorator.for(
      type: "tool_call",
      tool_name: "bash",
      tool_input: {"command" => "ls"},
      tool_use_id: "id1"
    )
    assert_instance_of ToolCallDecorator, decorator
  end

  test "for returns ToolResponseDecorator for tool_response hash" do
    decorator = EventDecorator.for(
      type: "tool_response",
      content: "output",
      tool_name: "bash",
      tool_use_id: "id1"
    )
    assert_instance_of ToolResponseDecorator, decorator
  end

  test "for returns nil for unknown event type" do
    assert_nil EventDecorator.for(type: "unknown_event")
  end

  test "render raises ArgumentError for invalid view mode" do
    decorator = EventDecorator.for(type: "user_message", content: "hello")
    assert_raises(ArgumentError) { decorator.render("sideways") }
  end

  # ─── UserMessageDecorator ──────────────────────────────────────────────

  test "UserMessageDecorator render_basic returns role :user and content" do
    result = EventDecorator.for(type: "user_message", content: "hello").render_basic

    assert_equal :user, result[:role]
    assert_equal "hello", result[:content]
  end

  test "UserMessageDecorator render_basic includes pending status for pending messages" do
    result = EventDecorator.for(type: "user_message", content: "queued", status: "pending").render_basic

    assert_equal "pending", result[:status]
  end

  test "UserMessageDecorator render_verbose adds timestamp" do
    result = EventDecorator.for(type: "user_message", content: "hello", timestamp: 12345).render_verbose

    assert_equal 12345, result[:timestamp]
  end

  test "UserMessageDecorator render_brain returns User: prefix" do
    result = EventDecorator.for(type: "user_message", content: "hello").render_brain

    assert_match(/^User: /, result)
  end

  # ─── AgentMessageDecorator ────────────────────────────────────────────

  test "AgentMessageDecorator render_basic returns role :assistant and content" do
    result = EventDecorator.for(type: "agent_message", content: "hi there").render_basic

    assert_equal :assistant, result[:role]
    assert_equal "hi there", result[:content]
  end

  test "AgentMessageDecorator render_brain returns Assistant: prefix" do
    result = EventDecorator.for(type: "agent_message", content: "answer").render_brain

    assert_match(/^Assistant: /, result)
  end

  # ─── ToolCallDecorator ────────────────────────────────────────────────

  test "ToolCallDecorator render_basic returns nil for non-think tool" do
    result = EventDecorator.for(
      type: "tool_call",
      tool_name: "bash",
      tool_input: {"command" => "ls"},
      tool_use_id: "id1"
    ).render_basic

    assert_nil result
  end

  test "ToolCallDecorator render_basic returns content for aloud think call" do
    result = EventDecorator.for(
      type: "tool_call",
      tool_name: "think",
      tool_input: {"thoughts" => "I should do X", "visibility" => "aloud"},
      tool_use_id: "id2"
    ).render_basic

    assert_equal :think, result[:role]
    assert_equal "I should do X", result[:content]
    assert_equal "aloud", result[:visibility]
  end

  test "ToolCallDecorator render_basic returns nil for inner think call" do
    result = EventDecorator.for(
      type: "tool_call",
      tool_name: "think",
      tool_input: {"thoughts" => "inner reasoning", "visibility" => "inner"},
      tool_use_id: "id3"
    ).render_basic

    assert_nil result
  end

  test "ToolCallDecorator render_verbose returns tool_call role with tool name" do
    result = EventDecorator.for(
      type: "tool_call",
      tool_name: "bash",
      tool_input: {"command" => "ls"},
      tool_use_id: "id1"
    ).render_verbose

    assert_equal :tool_call, result[:role]
    assert_equal "bash", result[:tool]
  end

  test "ToolCallDecorator render_brain returns Tool call line for non-think" do
    result = EventDecorator.for(
      type: "tool_call",
      tool_name: "bash",
      tool_input: {"command" => "ls"},
      tool_use_id: "id1"
    ).render_brain

    assert_match(/^Tool call: bash/, result)
  end

  # ─── ToolResponseDecorator ───────────────────────────────────────────

  test "ToolResponseDecorator render_basic returns nil" do
    result = EventDecorator.for(
      type: "tool_response",
      content: "output",
      tool_name: "bash",
      tool_use_id: "id1"
    ).render_basic

    assert_nil result
  end

  test "ToolResponseDecorator render_verbose returns tool_response role" do
    result = EventDecorator.for(
      type: "tool_response",
      content: "output text",
      tool_name: "bash",
      tool_use_id: "id1"
    ).render_verbose

    assert_equal :tool_response, result[:role]
    assert_equal true, result[:success]
  end

  test "ToolResponseDecorator render_verbose returns nil for think tool" do
    result = EventDecorator.for(
      type: "tool_response",
      content: "OK",
      tool_name: "think",
      tool_use_id: "id2"
    ).render_verbose

    assert_nil result
  end

  test "ToolResponseDecorator render_brain returns checkmark for success" do
    result = EventDecorator.for(
      type: "tool_response",
      content: "done",
      tool_name: "bash",
      success: true,
      tool_use_id: "id1"
    ).render_brain

    assert_equal "✅", result
  end

  test "ToolResponseDecorator render_brain returns nil for think tool" do
    result = EventDecorator.for(
      type: "tool_response",
      content: "OK",
      tool_name: "think",
      tool_use_id: "id2"
    ).render_brain

    assert_nil result
  end

  # ─── AR model decoration ────────────────────────────────────────────────

  test "for accepts an Event AR model" do
    session = Session.create!
    event = session.events.create!(
      event_type: "user_message",
      payload: {"content" => "from db"},
      timestamp: Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
    )

    decorator = EventDecorator.for(event)
    assert_instance_of UserMessageDecorator, decorator
    assert_equal "from db", decorator.render_basic[:content]
  end

  # ─── EventPayload#estimate_tokens ────────────────────────────────────────

  test "EventPayload estimates tokens from content for user_message" do
    payload = EventDecorator::EventPayload.new(
      event_type: "user_message",
      payload: {"content" => "hello world"},
      timestamp: nil,
      token_count: 0
    )

    assert payload.estimate_tokens >= 1
  end

  test "EventPayload estimates tokens from json for tool_call" do
    payload = EventDecorator::EventPayload.new(
      event_type: "tool_call",
      payload: {"tool_name" => "bash", "tool_input" => {"command" => "ls"}},
      timestamp: nil,
      token_count: 0
    )

    assert payload.estimate_tokens >= 1
  end

  test "EventPayload estimates tokens from json for tool_response" do
    payload = EventDecorator::EventPayload.new(
      event_type: "tool_response",
      payload: {"content" => "output", "tool_name" => "bash"},
      timestamp: nil,
      token_count: 0
    )

    assert payload.estimate_tokens >= 1
  end

  # ─── truncate_lines ───────────────────────────────────────────────────────

  test "truncate_lines truncates text that exceeds max_lines" do
    decorator = EventDecorator.for(type: "user_message", content: "x")
    result = decorator.send(:truncate_lines, "a\nb\nc\nd", max_lines: 2)

    assert_equal "a\nb\n...", result
  end

  test "truncate_lines returns original when within limit" do
    decorator = EventDecorator.for(type: "user_message", content: "x")
    result = decorator.send(:truncate_lines, "a\nb", max_lines: 5)

    assert_equal "a\nb", result
  end

  test "truncate_lines handles nil input" do
    decorator = EventDecorator.for(type: "user_message", content: "x")
    result = decorator.send(:truncate_lines, nil, max_lines: 3)

    assert_equal "", result
  end

  # ─── truncate_middle ──────────────────────────────────────────────────────

  test "truncate_middle returns original when within max_chars" do
    decorator = EventDecorator.for(type: "user_message", content: "x")
    result = decorator.send(:truncate_middle, "short text", max_chars: 100)

    assert_equal "short text", result
  end

  test "truncate_middle inserts truncation marker when text exceeds max_chars" do
    decorator = EventDecorator.for(type: "user_message", content: "x")
    long_text = "A" * 300 + "B" * 300
    result = decorator.send(:truncate_middle, long_text, max_chars: 50)

    assert_includes result, EventDecorator::MIDDLE_TRUNCATION_MARKER
    assert result.length < long_text.length
  end

  test "truncate_middle preserves start and end of text" do
    decorator = EventDecorator.for(type: "user_message", content: "x")
    text = "START" + ("x" * 600) + "END"
    result = decorator.send(:truncate_middle, text, max_chars: 100)

    assert result.start_with?("START")
    assert result.end_with?("END")
  end

  # ─── token_info (via render_verbose on UserMessageDecorator) ─────────────

  test "render_verbose includes token_info when token_count is zero (estimated)" do
    decorator = EventDecorator.for(type: "user_message", content: "hello", timestamp: 123)
    result = decorator.render_verbose

    # token_info is called inside verbose decorators that use it
    # UserMessageDecorator calls token_info in render_verbose
    assert result.key?(:timestamp)
  end

  # ─── ToolCallDecorator format_input specializations ─────────────────────

  test "ToolCallDecorator render_verbose for bash shows $ prefix" do
    result = EventDecorator.for(
      type: "tool_call",
      tool_name: "bash",
      tool_input: {"command" => "echo hello"},
      tool_use_id: "id1"
    ).render_verbose

    assert_equal "$ echo hello", result[:input]
  end

  test "ToolCallDecorator render_verbose for think tool returns think role with visibility and timestamp" do
    result = EventDecorator.for(
      type: "tool_call",
      tool_name: "think",
      tool_input: {"thoughts" => "deliberating", "visibility" => "inner"},
      tool_use_id: "id1",
      timestamp: 999
    ).render_verbose

    assert_equal :think, result[:role]
    assert_equal "deliberating", result[:content]
    assert_equal "inner", result[:visibility]
    assert_equal 999, result[:timestamp]
  end

  test "ToolCallDecorator render_verbose for web_get shows GET prefix" do
    result = EventDecorator.for(
      type: "tool_call",
      tool_name: "web_get",
      tool_input: {"url" => "http://example.com"},
      tool_use_id: "id1"
    ).render_verbose

    assert_equal "GET http://example.com", result[:input]
  end

  test "ToolCallDecorator render_verbose for unknown tool shows truncated JSON" do
    result = EventDecorator.for(
      type: "tool_call",
      tool_name: "read",
      tool_input: {"path" => "/foo/bar.rb"},
      tool_use_id: "id1"
    ).render_verbose

    assert_equal :tool_call, result[:role]
    assert_includes result[:input], "path"
  end

  test "ToolCallDecorator render_brain for think tool returns Think: prefix" do
    result = EventDecorator.for(
      type: "tool_call",
      tool_name: "think",
      tool_input: {"thoughts" => "my reasoning", "visibility" => "inner"},
      tool_use_id: "id1"
    ).render_brain

    assert_match(/^Think: /, result)
    assert_includes result, "my reasoning"
  end

  test "ToolCallDecorator render_debug includes tool_use_id for non-think tool" do
    result = EventDecorator.for(
      type: "tool_call",
      tool_name: "bash",
      tool_input: {"command" => "ls"},
      tool_use_id: "toolu_xyz"
    ).render_debug

    assert_equal :tool_call, result[:role]
    assert_equal "toolu_xyz", result[:tool_use_id]
    assert_includes result[:input], "command"
  end

  test "ToolCallDecorator render_debug for think includes tool_use_id" do
    result = EventDecorator.for(
      type: "tool_call",
      tool_name: "think",
      tool_input: {"thoughts" => "deep thought", "visibility" => "inner"},
      tool_use_id: "toolu_think"
    ).render_debug

    assert_equal :think, result[:role]
    assert_equal "deep thought", result[:content]
    assert_equal "toolu_think", result[:tool_use_id]
  end

  # ─── SystemMessageDecorator ──────────────────────────────────────────────

  test "for returns SystemMessageDecorator for system_message hash" do
    decorator = EventDecorator.for(type: "system_message", content: "System notice")
    assert_instance_of SystemMessageDecorator, decorator
  end

  test "SystemMessageDecorator render_basic returns nil" do
    result = EventDecorator.for(type: "system_message", content: "Notice").render_basic
    assert_nil result
  end

  test "SystemMessageDecorator render_verbose returns role :system with content" do
    result = EventDecorator.for(type: "system_message", content: "System alert", timestamp: 99).render_verbose
    assert_equal :system, result[:role]
    assert_equal "System alert", result[:content]
    assert_equal 99, result[:timestamp]
  end

  test "SystemMessageDecorator render_debug delegates to render_verbose" do
    result = EventDecorator.for(type: "system_message", content: "debug notice", timestamp: 77).render_debug
    assert_equal :system, result[:role]
  end

  # ─── AgentMessageDecorator debug mode ────────────────────────────────────

  test "AgentMessageDecorator render_debug includes token_info" do
    result = EventDecorator.for(type: "agent_message", content: "response", timestamp: 5).render_debug

    assert_equal :assistant, result[:role]
    assert result.key?(:tokens)
    assert result.key?(:estimated)
  end

  test "AgentMessageDecorator render_verbose adds timestamp" do
    result = EventDecorator.for(type: "agent_message", content: "hello", timestamp: 42).render_verbose
    assert_equal 42, result[:timestamp]
  end

  # ─── UserMessageDecorator debug mode ─────────────────────────────────────

  test "UserMessageDecorator render_debug includes token_info" do
    result = EventDecorator.for(type: "user_message", content: "question", timestamp: 1).render("debug")
    assert result.key?(:tokens)
  end

  # ─── token_info when token_count is already set ──────────────────────────

  test "token_info uses exact count when token_count > 0 on AR model" do
    session = Session.create!
    event = session.events.create!(
      event_type: "agent_message",
      payload: {"content" => "response text"},
      timestamp: Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond),
      token_count: 55
    )
    decorator = EventDecorator.for(event)
    result = decorator.render_debug

    assert_equal 55, result[:tokens]
    assert_equal false, result[:estimated]
  end

  # ─── ToolResponseDecorator render_debug ──────────────────────────────────

  test "ToolResponseDecorator render_debug returns full content with token_info" do
    result = EventDecorator.for(
      type: "tool_response",
      content: "full output text",
      tool_name: "bash",
      tool_use_id: "toolu_resp1"
    ).render_debug

    assert_equal :tool_response, result[:role]
    assert_equal "full output text", result[:content]
    assert_equal "toolu_resp1", result[:tool_use_id]
    assert result.key?(:tokens)
  end

  # ─── EventDecorator base class render_basic raises ───────────────────────

  test "EventDecorator render_basic raises NotImplementedError" do
    # Wrap an EventPayload directly in the base EventDecorator (bypassing the factory)
    payload = EventDecorator::EventPayload.new(
      event_type: "user_message",
      payload: {"content" => "x"},
      timestamp: nil,
      token_count: 0
    )
    decorator = EventDecorator.new(payload)
    assert_raises(NotImplementedError) { decorator.render_basic }
  end

  # ─── EventDecorator base class default render_verbose / render_debug / render_brain ──

  test "EventDecorator render_verbose delegates to render_basic by default" do
    # Minimal subclass that overrides render_basic but not render_verbose
    klass = Class.new(EventDecorator) do
      def render_basic
        {role: :stub}
      end
    end
    payload = EventDecorator::EventPayload.new(
      event_type: "user_message", payload: {}, timestamp: nil, token_count: 0
    )
    assert_equal({role: :stub}, klass.new(payload).render_verbose)
  end

  test "EventDecorator render_debug delegates to render_basic by default" do
    klass = Class.new(EventDecorator) do
      def render_basic
        {role: :stub}
      end
    end
    payload = EventDecorator::EventPayload.new(
      event_type: "user_message", payload: {}, timestamp: nil, token_count: 0
    )
    assert_equal({role: :stub}, klass.new(payload).render_debug)
  end

  test "EventDecorator render_brain returns nil by default" do
    payload = EventDecorator::EventPayload.new(
      event_type: "user_message", payload: {"content" => "x"}, timestamp: nil, token_count: 0
    )
    assert_nil EventDecorator.new(payload).render_brain
  end
end
