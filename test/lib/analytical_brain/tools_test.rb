# frozen_string_literal: true

require "test_helper"

# Tests for all AnalyticalBrain::Tools using real Session/Goal/Skills DB records.
# Each tool class gets its own nested test class to keep setup isolated.

class AnalyticalBrain::ActivateSkillToolTest < ActiveSupport::TestCase
  def setup
    Skills::Definition  # force autoload so InvalidDefinitionError is defined
    @session = Session.create!
    @tool = AnalyticalBrain::Tools::ActivateSkill.new(main_session: @session)
    Skills::Registry.reload!
  end

  test "params_schema returns an object schema with name property" do
    schema = AnalyticalBrain::Tools::ActivateSkill.new(main_session: @session).params_schema
    assert_equal "object", schema["type"]
    assert schema["properties"].key?("name")
  end

  test "call activates a skill and returns confirmation" do
    result = @tool.call("name" => "gh-issue")

    assert_kind_of String, result
    assert_includes result, "gh-issue"
    assert_includes @session.reload.active_skills, "gh-issue"
  end

  test "call returns error for blank name" do
    result = @tool.call("name" => "")

    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "call returns error for unknown skill" do
    result = @tool.call("name" => "no-such-skill")

    assert_kind_of Hash, result
    assert result.key?(:error)
  end
end

class AnalyticalBrain::DeactivateSkillToolTest < ActiveSupport::TestCase
  def setup
    Skills::Definition
    @session = Session.create!
    Skills::Registry.reload!
    @session.activate_skill("gh-issue")
    @tool = AnalyticalBrain::Tools::DeactivateSkill.new(main_session: @session)
  end

  test "params_schema returns an object schema" do
    schema = AnalyticalBrain::Tools::DeactivateSkill.new(main_session: @session).params_schema
    assert_equal "object", schema["type"]
  end

  test "call deactivates an active skill and returns confirmation" do
    result = @tool.call("name" => "gh-issue")

    assert_kind_of String, result
    assert_includes result, "gh-issue"
    assert_not_includes @session.reload.active_skills, "gh-issue"
  end

  test "call is a no-op for inactive skill" do
    assert_nothing_raised { @tool.call("name" => "nonexistent-skill") }
  end

  test "call returns error for blank name" do
    result = @tool.call("name" => "")

    assert_kind_of Hash, result
    assert result.key?(:error)
  end
end

class AnalyticalBrain::DeactivateWorkflowToolTest < ActiveSupport::TestCase
  def setup
    @session = Session.create!(active_workflow: "deploy-workflow")
    @tool = AnalyticalBrain::Tools::DeactivateWorkflow.new(main_session: @session)
  end

  test "params_schema returns an object schema" do
    schema = AnalyticalBrain::Tools::DeactivateWorkflow.new(main_session: @session).params_schema
    assert_equal "object", schema["type"]
  end

  test "call clears active_workflow and returns previous name" do
    result = @tool.call({})

    assert_includes result, "deploy-workflow"
    assert_nil @session.reload.active_workflow
  end

  test "call returns 'No workflow was active' when none set" do
    session = Session.create!
    tool = AnalyticalBrain::Tools::DeactivateWorkflow.new(main_session: session)
    result = tool.call({})

    assert_includes result, "No workflow was active"
  end
end

class AnalyticalBrain::EverythingIsReadyToolTest < ActiveSupport::TestCase
  test "call returns acknowledgement string" do
    tool = AnalyticalBrain::Tools::EverythingIsReady.new
    result = tool.call({})

    assert_kind_of String, result
    assert_match(/no changes needed/i, result)
  end

  test "tool_name is everything_is_ready" do
    assert_equal "everything_is_ready", AnalyticalBrain::Tools::EverythingIsReady.tool_name
  end

  test "params_schema has no required properties" do
    schema = AnalyticalBrain::Tools::EverythingIsReady.new.params_schema
    assert_equal [], schema["required"]
    assert_equal({}, schema["properties"])
  end
end

class AnalyticalBrain::FinishGoalToolTest < ActiveSupport::TestCase
  def setup
    @session = Session.create!
    @goal = @session.goals.create!(description: "Write tests")
    @tool = AnalyticalBrain::Tools::FinishGoal.new(main_session: @session)
  end

  test "params_schema returns an object schema with goal_id property" do
    schema = AnalyticalBrain::Tools::FinishGoal.new(main_session: @session).params_schema
    assert_equal "object", schema["type"]
    assert schema["properties"].key?("goal_id")
  end

  test "call marks goal as completed" do
    @tool.call("goal_id" => @goal.id)

    assert @goal.reload.completed?
  end

  test "call returns confirmation with goal description" do
    result = @tool.call("goal_id" => @goal.id)

    assert_includes result, "Write tests"
    assert_includes result, @goal.id.to_s
  end

  test "call returns error for unknown goal_id" do
    result = @tool.call("goal_id" => 999_999)

    assert_kind_of Hash, result
    assert_match(/not found/i, result[:error])
  end

  test "call returns error for already completed goal" do
    @goal.update!(status: "completed", completed_at: Time.current)
    result = @tool.call("goal_id" => @goal.id)

    assert_kind_of Hash, result
    assert_match(/already completed/i, result[:error])
  end

  test "call cascades completion to sub-goals" do
    sub = @session.goals.create!(description: "Sub-task", parent_goal_id: @goal.id)
    @tool.call("goal_id" => @goal.id)

    assert sub.reload.completed?
  end
end

class AnalyticalBrain::SetGoalToolTest < ActiveSupport::TestCase
  def setup
    @session = Session.create!
    @tool = AnalyticalBrain::Tools::SetGoal.new(main_session: @session)
  end

  test "params_schema returns an object schema with description property" do
    schema = AnalyticalBrain::Tools::SetGoal.new(main_session: @session).params_schema
    assert_equal "object", schema["type"]
    assert schema["properties"].key?("description")
  end

  test "call creates a root goal and returns confirmation" do
    result = @tool.call("description" => "Implement authentication")

    assert_includes result, "Goal created"
    assert_includes result, "Implement authentication"
    assert_equal 1, @session.goals.count
  end

  test "call creates a sub-goal when parent_goal_id provided" do
    parent = @session.goals.create!(description: "Parent")
    result = @tool.call("description" => "Sub-task", "parent_goal_id" => parent.id)

    assert_includes result, "Sub-goal created"
    sub = @session.goals.find_by(description: "Sub-task")
    assert_equal parent.id, sub.parent_goal_id
  end

  test "call returns error for blank description" do
    result = @tool.call("description" => "")

    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "call returns error when sub-goal nesting depth exceeded" do
    parent = @session.goals.create!(description: "Root")
    child = @session.goals.create!(description: "Child", parent_goal_id: parent.id)
    result = @tool.call("description" => "Grandchild", "parent_goal_id" => child.id)

    assert_kind_of Hash, result
    assert result.key?(:error)
  end
end

class AnalyticalBrain::UpdateGoalToolTest < ActiveSupport::TestCase
  def setup
    @session = Session.create!
    @goal = @session.goals.create!(description: "Original description")
    @tool = AnalyticalBrain::Tools::UpdateGoal.new(main_session: @session)
  end

  test "params_schema returns an object schema with goal_id property" do
    schema = AnalyticalBrain::Tools::UpdateGoal.new(main_session: @session).params_schema
    assert_equal "object", schema["type"]
    assert schema["properties"].key?("goal_id")
  end

  test "call updates goal description and returns confirmation" do
    result = @tool.call("goal_id" => @goal.id, "description" => "Revised description")

    assert_includes result, "Revised description"
    assert_equal "Revised description", @goal.reload.description
  end

  test "call returns error for blank description" do
    result = @tool.call("goal_id" => @goal.id, "description" => "")

    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "call returns error for unknown goal_id" do
    result = @tool.call("goal_id" => 999_999, "description" => "New")

    assert_kind_of Hash, result
    assert_match(/not found/i, result[:error])
  end

  test "call returns error for completed goal" do
    @goal.update!(status: "completed", completed_at: Time.current)
    result = @tool.call("goal_id" => @goal.id, "description" => "New")

    assert_kind_of Hash, result
    assert_match(/completed/i, result[:error])
  end
end

class AnalyticalBrain::RenameSessionToolTest < ActiveSupport::TestCase
  def setup
    @session = Session.create!
    @tool = AnalyticalBrain::Tools::RenameSession.new(main_session: @session)
  end

  test "params_schema returns an object schema with emoji and name properties" do
    schema = AnalyticalBrain::Tools::RenameSession.new(main_session: @session).params_schema
    assert_equal "object", schema["type"]
    assert schema["properties"].key?("emoji")
    assert schema["properties"].key?("name")
  end

  test "call updates session name with emoji and name" do
    @tool.call("emoji" => "🔧", "name" => "Test Suite")

    assert_equal "🔧 Test Suite", @session.reload.name
  end

  test "call returns confirmation message" do
    result = @tool.call("emoji" => "🚀", "name" => "Deploy")

    assert_includes result, "🚀 Deploy"
  end

  test "call returns error for blank emoji" do
    result = @tool.call("emoji" => "", "name" => "Something")

    assert_kind_of Hash, result
    assert_match(/emoji/i, result[:error])
  end

  test "call returns error for blank name" do
    result = @tool.call("emoji" => "🔧", "name" => "")

    assert_kind_of Hash, result
    assert_match(/name/i, result[:error])
  end
end

class AnalyticalBrain::ReadWorkflowToolTest < ActiveSupport::TestCase
  def setup
    Workflows::Definition  # force autoload so InvalidDefinitionError is defined
    @session = Session.create!
    @tool = AnalyticalBrain::Tools::ReadWorkflow.new(main_session: @session)

    # Create a temp workflow for happy-path tests
    @tmpdir = Dir.mktmpdir("brain_workflow_test")
    File.write(File.join(@tmpdir, "test-flow.md"), <<~MD)
      ---
      name: test-flow
      description: "A test workflow."
      ---
      ## Step 1
      Do the thing.
    MD
    registry = Workflows::Registry.new
    registry.load_directory(@tmpdir)
    Workflows::Registry.instance_variable_set(:@instance, registry)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
    Workflows::Registry.reload!
  end

  test "params_schema returns an object schema with name property" do
    schema = AnalyticalBrain::Tools::ReadWorkflow.new(main_session: @session).params_schema
    assert_equal "object", schema["type"]
    assert schema["properties"].key?("name")
  end

  test "call activates workflow and returns formatted content" do
    result = @tool.call("name" => "test-flow")

    assert_kind_of String, result
    assert_includes result, "test-flow"
    assert_includes result, "A test workflow."
    assert_equal "test-flow", @session.reload.active_workflow
  end

  test "call returns error for blank name" do
    result = @tool.call("name" => "")

    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "call returns error for unknown workflow" do
    result = @tool.call("name" => "no-such-workflow")

    assert_kind_of Hash, result
    assert result.key?(:error)
  end
end
