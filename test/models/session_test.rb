# frozen_string_literal: true

require "test_helper"
require "tempfile"

class SessionTest < ActiveSupport::TestCase
  def setup
    @session = Session.create!
  end

  # ─── Validations ─────────────────────────────────────────────────────────

  test "valid with default view_mode" do
    assert @session.valid?
  end

  test "rejects invalid view_mode" do
    session = Session.new(view_mode: "sideways")
    assert_not session.valid?
    assert_includes session.errors[:view_mode], "is not included in the list"
  end

  test "rejects name longer than 255 characters" do
    session = Session.new(view_mode: "basic", name: "x" * 256)
    assert_not session.valid?
  end

  test "allows nil name" do
    session = Session.new(view_mode: "basic", name: nil)
    assert session.valid?
  end

  # ─── Hierarchy ───────────────────────────────────────────────────────────

  test "sub_agent? returns false for a root session" do
    assert_not @session.sub_agent?
  end

  test "sub_agent? returns true for a child session" do
    child = Session.create!(parent_session: @session)
    assert child.sub_agent?
  end

  test "child_sessions association returns spawned sub-agents" do
    child1 = Session.create!(parent_session: @session)
    child2 = Session.create!(parent_session: @session)

    assert_includes @session.child_sessions, child1
    assert_includes @session.child_sessions, child2
  end

  # ─── View mode ───────────────────────────────────────────────────────────

  test "next_view_mode cycles basic → verbose → debug → basic" do
    @session.view_mode = "basic"
    assert_equal "verbose", @session.next_view_mode

    @session.view_mode = "verbose"
    assert_equal "debug", @session.next_view_mode

    @session.view_mode = "debug"
    assert_equal "basic", @session.next_view_mode
  end

  # ─── Skills ──────────────────────────────────────────────────────────────

  test "activate_skill adds skill name to active_skills" do
    Skills::Registry.reload!
    @session.activate_skill("gh-issue")
    assert_includes @session.active_skills, "gh-issue"
  end

  test "activate_skill persists the change" do
    Skills::Registry.reload!
    @session.activate_skill("gh-issue")
    assert_includes @session.reload.active_skills, "gh-issue"
  end

  test "activate_skill is idempotent" do
    Skills::Registry.reload!
    @session.activate_skill("gh-issue")
    @session.activate_skill("gh-issue")
    assert_equal 1, @session.active_skills.count("gh-issue")
  end

  test "activate_skill raises for unknown skill" do
    Skills::Registry.reload!
    assert_raises(Skills::InvalidDefinitionError) do
      @session.activate_skill("nonexistent-skill")
    end
  end

  test "deactivate_skill removes skill from active_skills" do
    Skills::Registry.reload!
    @session.activate_skill("gh-issue")
    @session.deactivate_skill("gh-issue")
    assert_not_includes @session.active_skills, "gh-issue"
  end

  test "deactivate_skill persists the change" do
    Skills::Registry.reload!
    @session.activate_skill("gh-issue")
    @session.deactivate_skill("gh-issue")
    assert_not_includes @session.reload.active_skills, "gh-issue"
  end

  test "deactivate_skill is a no-op when skill is not active" do
    assert_nothing_raised { @session.deactivate_skill("gh-issue") }
  end

  # ─── Workflows ───────────────────────────────────────────────────────────

  test "activate_workflow raises for unknown workflow" do
    Workflows::Definition  # ensure definition.rb is loaded so InvalidDefinitionError is defined
    assert_raises(Workflows::InvalidDefinitionError) do
      @session.activate_workflow("nonexistent-workflow")
    end
  end

  test "deactivate_workflow clears active_workflow" do
    @session.update!(active_workflow: "some-workflow")
    @session.deactivate_workflow
    assert_nil @session.active_workflow
  end

  test "deactivate_workflow is a no-op when no workflow is active" do
    assert_nothing_raised { @session.deactivate_workflow }
  end

  # ─── Pending messages ────────────────────────────────────────────────────

  test "promote_pending_messages! changes status to nil" do
    @session.events.create!(
      event_type: "user_message",
      payload: {content: "queued"},
      timestamp: 1,
      status: "pending"
    )

    count = @session.promote_pending_messages!

    assert_equal 1, count
    assert_equal 0, @session.events.pending.count
  end

  test "promote_pending_messages! only promotes pending messages" do
    @session.events.create!(
      event_type: "user_message",
      payload: {content: "delivered"},
      timestamp: 1
    )
    @session.events.create!(
      event_type: "user_message",
      payload: {content: "queued"},
      timestamp: 2,
      status: "pending"
    )

    count = @session.promote_pending_messages!

    assert_equal 1, count
    assert_equal 0, @session.events.pending.count
    assert_equal 2, @session.events.deliverable.count
  end

  # ─── messages_for_llm ───────────────────────────────────────────────────

  test "messages_for_llm returns user and agent messages in role format" do
    @session.events.create!(event_type: "user_message", payload: {"content" => "hello"}, timestamp: 1)
    @session.events.create!(event_type: "agent_message", payload: {"content" => "hi there"}, timestamp: 2)

    messages = @session.messages_for_llm

    assert_equal 2, messages.size
    assert_equal "user", messages[0][:role]
    assert_includes messages[0][:content], "hello"
    assert_equal "assistant", messages[1][:role]
    assert_equal "hi there", messages[1][:content]
  end

  test "messages_for_llm excludes pending messages" do
    @session.events.create!(
      event_type: "user_message",
      payload: {"content" => "delivered"},
      timestamp: 1
    )
    @session.events.create!(
      event_type: "user_message",
      payload: {"content" => "queued"},
      timestamp: 2,
      status: "pending"
    )

    messages = @session.messages_for_llm

    assert_equal 1, messages.size
    assert_includes messages[0][:content], "delivered"
  end

  test "messages_for_llm groups consecutive tool_call events into one assistant message" do
    @session.events.create!(
      event_type: "tool_call",
      payload: {"content" => "x", "tool_name" => "bash", "tool_use_id" => "id1", "tool_input" => {}},
      timestamp: 1
    )
    @session.events.create!(
      event_type: "tool_call",
      payload: {"content" => "x", "tool_name" => "think", "tool_use_id" => "id2", "tool_input" => {}},
      timestamp: 2
    )

    messages = @session.messages_for_llm

    assert_equal 1, messages.size
    assert_equal "assistant", messages[0][:role]
    assert_equal 2, messages[0][:content].size
  end

  test "messages_for_llm prepends timestamp to user messages" do
    ts = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
    @session.events.create!(event_type: "user_message", payload: {"content" => "hello"}, timestamp: ts)

    messages = @session.messages_for_llm

    assert_match(/\w{3} \w{3}/, messages[0][:content])
  end

  # ─── viewport_events ────────────────────────────────────────────────────

  test "viewport_events returns events ordered chronologically" do
    e1 = @session.events.create!(event_type: "user_message", payload: {content: "first"}, timestamp: 1)
    e2 = @session.events.create!(event_type: "agent_message", payload: {content: "second"}, timestamp: 2)

    events = @session.viewport_events
    ids = events.map(&:id)

    assert_equal [e1.id, e2.id], ids
  end

  test "viewport_events respects token budget by excluding oldest events first" do
    10.times do |i|
      @session.events.create!(
        event_type: "user_message",
        payload: {"content" => "message #{i}" * 100},
        timestamp: i + 1
      )
    end

    events = @session.viewport_events(token_budget: 50)

    assert events.size < 10
  end

  test "sub-agent viewport_events includes parent events" do
    parent_event = @session.events.create!(
      event_type: "user_message",
      payload: {content: "parent context"},
      timestamp: 1
    )

    child = Session.create!(parent_session: @session)
    child_event = child.events.create!(
      event_type: "agent_message",
      payload: {content: "child response"},
      timestamp: Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
    )

    events = child.viewport_events
    event_ids = events.map(&:id)

    assert_includes event_ids, parent_event.id
    assert_includes event_ids, child_event.id
  end

  # ─── schedule_analytical_brain! ─────────────────────────────────────────

  test "schedule_analytical_brain! is a no-op for sub-agents" do
    child = Session.create!(parent_session: @session)
    assert_no_enqueued_jobs { child.schedule_analytical_brain! }
  end

  test "schedule_analytical_brain! is a no-op when fewer than 2 llm_messages" do
    @session.events.create!(event_type: "user_message", payload: {content: "hi"}, timestamp: 1)
    assert_no_enqueued_jobs { @session.schedule_analytical_brain! }
  end

  test "schedule_analytical_brain! enqueues AnalyticalBrainJob when count >= 2 and no name" do
    @session.events.create!(event_type: "user_message", payload: {content: "hi"}, timestamp: 1)
    @session.events.create!(event_type: "agent_message", payload: {content: "hello"}, timestamp: 2)

    assert_enqueued_with(job: AnalyticalBrainJob) do
      @session.schedule_analytical_brain!
    end
  end

  # ─── snapshot_viewport! ──────────────────────────────────────────────────

  test "snapshot_viewport! stores the given ids" do
    @session.snapshot_viewport!([1, 2, 3])

    assert_equal [1, 2, 3], @session.reload.viewport_event_ids
  end

  # ─── system_prompt ───────────────────────────────────────────────────────

  test "system_prompt for sub-agent returns stored prompt" do
    child = Session.create!(parent_session: @session, prompt: "You are a sub-agent.")
    assert_equal "You are a sub-agent.", child.system_prompt
  end

  test "system_prompt raises MissingSoulError when soul file is absent" do
    original_path = Anima::Settings.config_path

    begin
      bad_config = Tempfile.new(["session_test_bad_config", ".toml"])
      bad_config.write(File.read(original_path).sub(/soul = ".*"/, 'soul = "/nonexistent/soul.md"'))
      bad_config.flush
      Anima::Settings.config_path = bad_config.path

      assert_raises(Session::MissingSoulError) { @session.system_prompt }
    ensure
      Anima::Settings.config_path = original_path
      bad_config&.close
      bad_config&.unlink
    end
  end

  # ─── activate_workflow happy path ────────────────────────────────────────

  test "activate_workflow sets active_workflow on the session" do
    registry = Workflows::Registry.reload!
    workflow_name = registry.available_names.first
    skip "no workflows to test with" unless workflow_name

    @session.activate_workflow(workflow_name)
    assert_equal workflow_name, @session.reload.active_workflow
  end

  test "activate_workflow is idempotent" do
    registry = Workflows::Registry.reload!
    workflow_name = registry.available_names.first
    skip "no workflows to test with" unless workflow_name

    @session.activate_workflow(workflow_name)
    definition = @session.activate_workflow(workflow_name)
    assert_equal workflow_name, @session.active_workflow
    assert_instance_of Workflows::Definition, definition
  end

  # ─── assemble_system_prompt (expertise, goals, soul) ────────────────────

  test "system_prompt for root session includes soul content" do
    result = @session.system_prompt

    soul_content = File.read(Anima::Settings.soul_path).strip
    assert_includes result, soul_content
  end

  test "system_prompt includes active skill content in expertise section" do
    Skills::Registry.reload!
    @session.activate_skill("gh-issue")

    result = @session.system_prompt

    assert_includes result, "Your Expertise"
  end

  test "system_prompt includes active workflow content in expertise section" do
    tmpdir = Dir.mktmpdir("session_workflow_expertise_test")
    File.write(File.join(tmpdir, "test-flow.md"), <<~MD)
      ---
      name: test-flow
      description: "A test workflow for expertise."
      ---
      ## Step 1
      Do the thing.
    MD
    registry = Workflows::Registry.new
    registry.load_directory(tmpdir)
    Workflows::Registry.instance_variable_set(:@instance, registry)
    @session.update!(active_workflow: "test-flow")

    result = @session.system_prompt

    assert_includes result, "Your Expertise"
    assert_includes result, "Do the thing."
  ensure
    Workflows::Registry.reload!
    FileUtils.remove_entry(tmpdir)
  end

  test "system_prompt includes goals section when goals exist" do
    @session.goals.create!(description: "Finish the project", status: "active")

    result = @session.system_prompt

    assert_includes result, "Current Goals"
    assert_includes result, "Finish the project"
  end

  test "system_prompt renders completed goals with strikethrough" do
    @session.goals.create!(description: "Done task", status: "completed")

    result = @session.system_prompt

    assert_includes result, "~~Done task~~"
  end

  test "system_prompt renders sub-goals as checkboxes" do
    root = @session.goals.create!(description: "Root goal", status: "active")
    root.sub_goals.create!(session: @session, description: "Sub-task", status: "active")

    result = @session.system_prompt

    assert_includes result, "[ ] Sub-task"
  end

  test "system_prompt renders completed sub-goals as checked" do
    root = @session.goals.create!(description: "Root goal", status: "active")
    root.sub_goals.create!(session: @session, description: "Done sub", status: "completed")

    result = @session.system_prompt

    assert_includes result, "[x] Done sub"
  end

  # ─── messages_for_llm with tool_response and system_message ─────────────

  test "messages_for_llm wraps system_message as user role with prefix" do
    @session.events.create!(
      event_type: "system_message",
      payload: {"content" => "Important notice"},
      timestamp: 1
    )

    messages = @session.messages_for_llm

    assert_equal 1, messages.size
    assert_equal "user", messages[0][:role]
    assert_includes messages[0][:content], "[system]"
    assert_includes messages[0][:content], "Important notice"
  end

  test "messages_for_llm groups consecutive tool_response events into one user message" do
    @session.events.create!(
      event_type: "tool_response",
      payload: {"content" => "result1", "tool_name" => "bash", "tool_use_id" => "id1"},
      timestamp: 1
    )
    @session.events.create!(
      event_type: "tool_response",
      payload: {"content" => "result2", "tool_name" => "think", "tool_use_id" => "id2"},
      timestamp: 2
    )

    messages = @session.messages_for_llm

    assert_equal 1, messages.size
    assert_equal "user", messages[0][:role]
    assert_equal 2, messages[0][:content].size
    assert messages[0][:content].all? { |b| b[:type] == "tool_result" }
  end

  # ─── Scopes ──────────────────────────────────────────────────────────────

  test "root_sessions scope excludes child sessions" do
    child = Session.create!(parent_session: @session)

    assert_includes Session.root_sessions, @session
    assert_not_includes Session.root_sessions, child
  end

  test "recent scope orders by updated_at descending" do
    older = Session.create!(updated_at: 1.hour.ago)
    newer = Session.create!(updated_at: Time.current)

    recents = Session.recent(2)
    assert_equal newer.id, recents.first.id
  end
end
