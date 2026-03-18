# frozen_string_literal: true

require "test_helper"

class Tools::SpawnSubagentTest < ActiveSupport::TestCase
  def setup
    @session = Session.create!
    @tool = Tools::SpawnSubagent.new(session: @session)
  end

  test "tool_name is spawn_subagent" do
    assert_equal "spawn_subagent", Tools::SpawnSubagent.tool_name
  end

  test "params_schema returns an object schema with task and expected_output properties" do
    schema = @tool.params_schema
    assert_equal "object", schema["type"]
    assert schema["properties"].key?("task")
    assert schema["properties"].key?("expected_output")
    assert schema["properties"].key?("tools")
  end

  test "call returns error for blank task" do
    result = @tool.call("task" => "", "expected_output" => "Something")

    assert_kind_of Hash, result
    assert_match(/blank/i, result[:error])
  end

  test "call returns error for blank expected_output" do
    result = @tool.call("task" => "Do something", "expected_output" => "")

    assert_kind_of Hash, result
    assert_match(/blank/i, result[:error])
  end

  test "call returns error for non-array tools parameter" do
    result = @tool.call("task" => "Do something", "expected_output" => "Result", "tools" => "bash")

    assert_kind_of Hash, result
    assert_match(/array/i, result[:error])
  end

  test "call returns error for unknown tool name" do
    result = @tool.call("task" => "Do something", "expected_output" => "Result", "tools" => ["no_such_tool"])

    assert_kind_of Hash, result
    assert_match(/unknown tool/i, result[:error])
  end

  test "call spawns a child session and returns confirmation" do
    assert_enqueued_with(job: AgentRequestJob) do
      result = @tool.call("task" => "Analyse the codebase", "expected_output" => "A summary")

      assert_kind_of String, result
      assert_includes result, "spawned"
    end

    assert_equal 1, @session.reload.child_sessions.count
  end

  test "call creates child session with parent link" do
    assert_enqueued_with(job: AgentRequestJob) do
      @tool.call("task" => "Do the thing", "expected_output" => "Done")
    end

    child = @session.child_sessions.first
    assert_equal @session.id, child.parent_session_id
  end

  test "call with valid tools array creates child session" do
    assert_enqueued_with(job: AgentRequestJob) do
      result = @tool.call("task" => "Read files", "expected_output" => "File list", "tools" => ["bash", "read"])

      assert_kind_of String, result
    end

    child = @session.child_sessions.first
    tools = JSON.parse(child.granted_tools)
    assert_includes tools, "bash"
    assert_includes tools, "read"
  end

  test "call with empty tools array creates child session with no granted tools" do
    assert_enqueued_with(job: AgentRequestJob) do
      @tool.call("task" => "Think hard", "expected_output" => "Answer", "tools" => [])
    end

    child = @session.child_sessions.first
    assert_empty JSON.parse(child.granted_tools)
  end

  test "call normalizes tool names to lowercase" do
    assert_enqueued_with(job: AgentRequestJob) do
      @tool.call("task" => "Do something", "expected_output" => "Result", "tools" => ["BASH", "Read"])
    end

    child = @session.child_sessions.first
    tools = JSON.parse(child.granted_tools)
    assert_includes tools, "bash"
    assert_includes tools, "read"
  end

  # ── spawn-depth guard ──────────────────────────────────────────────────────

  test "call returns error when session is at maximum spawn depth" do
    # Build a chain: root → child → grandchild (depth 2) → great-grandchild (depth 3 = MAX)
    root        = Session.create!
    child       = Session.create!(parent_session_id: root.id)
    grandchild  = Session.create!(parent_session_id: child.id)
    deep        = Session.create!(parent_session_id: grandchild.id)

    tool = Tools::SpawnSubagent.new(session: deep)
    result = tool.call("task" => "Do it", "expected_output" => "Done")

    assert_kind_of Hash, result
    assert_match(/maximum nesting depth/i, result[:error])
  end

  test "call succeeds when session is one level below maximum depth" do
    root   = Session.create!
    child  = Session.create!(parent_session_id: root.id)
    tool   = Tools::SpawnSubagent.new(session: child)

    assert_enqueued_with(job: AgentRequestJob) do
      result = tool.call("task" => "Do it", "expected_output" => "Done")
      assert_kind_of String, result
    end
  end

  test "ancestry_depth returns 0 for a root session" do
    assert_equal 0, Tools::SpawnSubagent.new(session: @session).send(:ancestry_depth)
  end

  test "ancestry_depth returns 1 for a direct child session" do
    child = Session.create!(parent_session_id: @session.id)
    assert_equal 1, Tools::SpawnSubagent.new(session: child).send(:ancestry_depth)
  end
end
