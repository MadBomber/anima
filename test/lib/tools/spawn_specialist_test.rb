# frozen_string_literal: true

require "test_helper"

class Tools::SpawnSpecialistTest < ActiveSupport::TestCase
  # A minimal stub registry with one known specialist.
  class FakeRegistry
    def initialize(agents = {})
      @agents = agents
    end

    def get(name) = @agents[name]
    def any? = @agents.any?
    def names = @agents.keys
    def catalog = @agents.transform_values(&:description)
  end

  def setup
    @session = Session.create!

    @definition = Agents::Definition.new(
      name: "test-specialist",
      description: "A test specialist",
      tools: ["bash", "read"],
      prompt: "You are a test specialist."
    )

    @registry = FakeRegistry.new("test-specialist" => @definition)
    @tool = Tools::SpawnSpecialist.new(session: @session, agent_registry: @registry)
  end

  test "tool_name is spawn_specialist" do
    assert_equal "spawn_specialist", Tools::SpawnSpecialist.tool_name
  end

  test "params_schema returns an object schema with name, task, expected_output" do
    schema = @tool.params_schema
    assert_equal "object", schema["type"]
    assert schema["properties"].key?("name")
    assert schema["properties"].key?("task")
    assert schema["properties"].key?("expected_output")
  end

  test "params_schema includes enum of agent names from the global registry" do
    # params_schema uses the class-level Agents::Registry.instance (global registry),
    # which is populated from the built-in agents/ directory.
    schema = @tool.params_schema
    enum = schema["properties"]["name"]["enum"]
    assert_kind_of Array, enum
    assert enum.any?, "expected at least one agent name in the enum"
  end

  test "call returns error for blank name" do
    result = @tool.call("name" => "", "task" => "Do it", "expected_output" => "Result")

    assert_kind_of Hash, result
    assert_match(/blank/i, result[:error])
  end

  test "call returns error for blank task" do
    result = @tool.call("name" => "test-specialist", "task" => "", "expected_output" => "Result")

    assert_kind_of Hash, result
    assert_match(/blank/i, result[:error])
  end

  test "call returns error for blank expected_output" do
    result = @tool.call("name" => "test-specialist", "task" => "Do it", "expected_output" => "")

    assert_kind_of Hash, result
    assert_match(/blank/i, result[:error])
  end

  test "call returns error for unknown agent name" do
    result = @tool.call("name" => "no-such-agent", "task" => "Do it", "expected_output" => "Result")

    assert_kind_of Hash, result
    assert_match(/unknown agent/i, result[:error])
  end

  test "call spawns a child session and returns confirmation" do
    assert_enqueued_with(job: AgentRequestJob) do
      result = @tool.call("name" => "test-specialist", "task" => "Analyze logs", "expected_output" => "Summary")

      assert_kind_of String, result
      assert_includes result, "test-specialist"
      assert_includes result, "spawned"
    end
  end

  test "call creates child session linked to parent" do
    assert_enqueued_with(job: AgentRequestJob) do
      @tool.call("name" => "test-specialist", "task" => "Do the thing", "expected_output" => "Done")
    end

    child = @session.child_sessions.first
    assert_not_nil child
    assert_equal @session.id, child.parent_session_id
  end

  test "call sets child session granted_tools from definition" do
    assert_enqueued_with(job: AgentRequestJob) do
      @tool.call("name" => "test-specialist", "task" => "Do the thing", "expected_output" => "Done")
    end

    child = @session.child_sessions.first
    assert_equal @definition.tools, JSON.parse(child.granted_tools)
  end

  # ── spawn-depth guard ──────────────────────────────────────────────────────

  test "call returns error when session is at maximum spawn depth" do
    root       = Session.create!
    child      = Session.create!(parent_session_id: root.id)
    grandchild = Session.create!(parent_session_id: child.id)
    deep       = Session.create!(parent_session_id: grandchild.id)

    tool = Tools::SpawnSpecialist.new(session: deep, agent_registry: @registry)
    result = tool.call("name" => "test-specialist", "task" => "Do it", "expected_output" => "Done")

    assert_kind_of Hash, result
    assert_match(/maximum nesting depth/i, result[:error])
  end
end
