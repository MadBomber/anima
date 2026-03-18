# frozen_string_literal: true

require "test_helper"

class GoalTest < ActiveSupport::TestCase
  def setup
    @session = Session.create!
  end

  # ─── Validations ─────────────────────────────────────────────────────────

  test "valid with required attributes" do
    goal = Goal.new(session: @session, description: "Finish feature X", status: "active")
    assert goal.valid?
  end

  test "requires description" do
    goal = Goal.new(session: @session, status: "active")
    assert_not goal.valid?
    assert_includes goal.errors[:description], "can't be blank"
  end

  test "rejects invalid status" do
    goal = Goal.new(session: @session, description: "Do something", status: "invalid")
    assert_not goal.valid?
    assert_includes goal.errors[:status], "is not included in the list"
  end

  test "accepts active and completed statuses" do
    %w[active completed].each do |status|
      goal = Goal.new(session: @session, description: "Goal", status: status)
      assert goal.valid?, "Expected status '#{status}' to be valid"
    end
  end

  test "rejects sub-goal belonging to different session" do
    other_session = Session.create!
    parent = @session.goals.create!(description: "Root", status: "active")
    sub = Goal.new(session: other_session, description: "Sub", status: "active", parent_goal: parent)
    assert_not sub.valid?
    assert_includes sub.errors[:parent_goal], "must belong to the same session"
  end

  test "rejects three-level nesting" do
    root = @session.goals.create!(description: "Root", status: "active")
    child = @session.goals.create!(description: "Child", status: "active", parent_goal: root)
    grandchild = Goal.new(session: @session, description: "Grandchild", status: "active", parent_goal: child)
    assert_not grandchild.valid?
    assert_includes grandchild.errors[:parent_goal], "cannot nest deeper than two levels"
  end

  # ─── Predicates ──────────────────────────────────────────────────────────

  test "completed? returns true when status is completed" do
    goal = @session.goals.create!(description: "Done", status: "completed")
    assert goal.completed?
  end

  test "completed? returns false when status is active" do
    goal = @session.goals.create!(description: "In progress", status: "active")
    assert_not goal.completed?
  end

  test "root? returns true when no parent" do
    goal = @session.goals.create!(description: "Root goal", status: "active")
    assert goal.root?
  end

  test "root? returns false when has parent" do
    parent = @session.goals.create!(description: "Root", status: "active")
    child = @session.goals.create!(description: "Sub", status: "active", parent_goal: parent)
    assert_not child.root?
  end

  # ─── Scopes ──────────────────────────────────────────────────────────────

  test "active scope returns only active goals" do
    active = @session.goals.create!(description: "Active", status: "active")
    done = @session.goals.create!(description: "Done", status: "completed")

    assert_includes Goal.active, active
    assert_not_includes Goal.active, done
  end

  test "root scope returns only root goals" do
    root = @session.goals.create!(description: "Root", status: "active")
    sub = @session.goals.create!(description: "Sub", status: "active", parent_goal: root)

    assert_includes Goal.root, root
    assert_not_includes Goal.root, sub
  end

  # ─── cascade_completion! ─────────────────────────────────────────────────

  test "cascade_completion! marks active sub-goals as completed" do
    root = @session.goals.create!(description: "Root", status: "active")
    sub1 = @session.goals.create!(description: "Sub 1", status: "active", parent_goal: root)
    sub2 = @session.goals.create!(description: "Sub 2", status: "active", parent_goal: root)

    root.cascade_completion!

    assert_equal "completed", sub1.reload.status
    assert_equal "completed", sub2.reload.status
  end

  test "cascade_completion! skips already-completed sub-goals" do
    root = @session.goals.create!(description: "Root", status: "active")
    done = @session.goals.create!(description: "Already done", status: "completed", parent_goal: root)

    root.cascade_completion!

    assert_equal "completed", done.reload.status
  end

  # ─── as_summary ──────────────────────────────────────────────────────────

  test "as_summary includes id, description, status, and sub_goals" do
    root = @session.goals.create!(description: "Root goal", status: "active")
    sub = @session.goals.create!(description: "Sub goal", status: "active", parent_goal: root)

    summary = root.as_summary

    assert_equal root.id, summary["id"]
    assert_equal "Root goal", summary["description"]
    assert_equal "active", summary["status"]
    assert_equal 1, summary["sub_goals"].size
    assert_equal sub.id, summary["sub_goals"].first["id"]
    assert_equal "Sub goal", summary["sub_goals"].first["description"]
  end

  test "as_summary returns empty sub_goals for root with no children" do
    root = @session.goals.create!(description: "Standalone goal", status: "active")
    assert_empty root.as_summary["sub_goals"]
  end
end
