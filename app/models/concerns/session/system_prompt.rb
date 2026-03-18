# frozen_string_literal: true

# Assembles the system prompt for main (non-sub-agent) sessions.
#
# The prompt is composed of up to four sections, joined with blank lines:
#   1. Soul    — the agent's self-authored identity (always present)
#   2. Environment — working directory context from EnvironmentProbe (optional)
#   3. Expertise — active skills and/or the active workflow (optional)
#   4. Goals   — active goals rendered as Markdown (optional)
#
# Sub-agent sessions use a stored prompt instead; see {Session#system_prompt}.
module Session::SystemPrompt
  extend ActiveSupport::Concern

  # Returns the system prompt for this session.
  # Sub-agents use their stored prompt. Main sessions assemble dynamically.
  #
  # @param environment_context [String, nil] pre-assembled environment block
  # @return [String, nil]
  def system_prompt(environment_context: nil)
    sub_agent? ? prompt : assemble_system_prompt(environment_context: environment_context)
  end

  # Assembles the full system prompt from its sections.
  #
  # @param environment_context [String, nil]
  # @return [String]
  def assemble_system_prompt(environment_context: nil)
    [
      assemble_soul_section,
      environment_context,
      assemble_expertise_section,
      assemble_goals_section
    ].compact.join("\n\n")
  end

  private

  # Reads the soul file — the agent's self-authored identity.
  #
  # @return [String]
  # @raise [Session::MissingSoulError] when the soul file does not exist
  def assemble_soul_section
    path = Anima::Settings.soul_path
    unless File.exist?(path)
      raise Session::MissingSoulError, "Soul file not found: #{path}. Run `anima install` to create it."
    end

    File.read(path).strip
  end

  # Assembles the expertise section from active skills and the active workflow.
  # Both are rendered identically as domain knowledge sections.
  #
  # @return [String, nil]
  def assemble_expertise_section
    sections = active_skills.filter_map do |skill_name|
      format_expertise_section(Skills::Registry.instance.find(skill_name), skill_name)
    end

    if active_workflow.present?
      definition = Workflows::Registry.instance.find(active_workflow)
      sections << format_expertise_section(definition, active_workflow) if definition
    end

    return if sections.empty?

    "## Your Expertise\n\nYou know this deeply. Now's your chance to put it to work.\n\n#{sections.join("\n\n")}"
  end

  # Assembles the goals section. Active goals render as headings with
  # sub-goal checkboxes; completed goals collapse to strikethrough.
  #
  # @return [String, nil]
  def assemble_goals_section
    root_goals = goals.root.includes(:sub_goals).order(:created_at)
    return if root_goals.empty?

    entries = root_goals.map { |goal| render_goal_markdown(goal) }
    "## Current Goals\n\n#{entries.join("\n\n")}"
  end

  # Renders a root goal and its sub-goals as Markdown.
  #
  # @param goal [Goal]
  # @return [String]
  def render_goal_markdown(goal)
    return "### ~~#{goal.description}~~ ✓" if goal.completed?

    lines = ["### #{goal.description}"]
    goal.sub_goals.each do |sub|
      checkbox = sub.completed? ? "[x]" : "[ ]"
      lines << "- #{checkbox} #{sub.description}"
    end
    lines.join("\n")
  end

  # Formats a skill or workflow definition as a Markdown section.
  # Extracts the first heading from content for the section title.
  #
  # @param definition [Skills::Definition, Workflows::Definition, nil]
  # @param fallback_name [String]
  # @return [String, nil]
  def format_expertise_section(definition, fallback_name)
    return unless definition

    content = definition.content
    heading = content.lines.first&.sub(/^#+ /, "")&.strip || fallback_name
    "### #{heading}\n\n#{content}"
  end
end
