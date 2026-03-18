# frozen_string_literal: true

# Manages the skill and workflow lifecycle on a Session.
#
# Skills are domain knowledge bundles injected into the agent's system prompt.
# Multiple skills can be active simultaneously; the analytical brain activates
# and deactivates them based on conversation context.
#
# Workflows are operational recipes — only one can be active at a time.
# Activating a new workflow replaces the previous one.
module Session::SkillsAndWorkflows
  extend ActiveSupport::Concern

  # Activates a skill on this session. Validates the skill exists in the
  # registry, adds it to active_skills, and persists.
  #
  # @param skill_name [String] name of the skill to activate
  # @return [Skills::Definition] the activated skill
  # @raise [Skills::InvalidDefinitionError] if skill not found in registry
  # @raise [ActiveRecord::RecordInvalid] if save fails
  def activate_skill(skill_name)
    definition = Skills::Registry.instance.find(skill_name)
    raise Skills::InvalidDefinitionError, "Unknown skill: #{skill_name}" unless definition

    return definition if active_skills.include?(skill_name)

    self.active_skills = active_skills + [skill_name]
    save!
    definition
  end

  # Deactivates a skill on this session. Removes it from active_skills and persists.
  #
  # @param skill_name [String] name of the skill to deactivate
  # @return [void]
  def deactivate_skill(skill_name)
    return unless active_skills.include?(skill_name)

    self.active_skills = active_skills - [skill_name]
    save!
  end

  # Activates a workflow on this session. Only one workflow can be active at a
  # time — activating a new one replaces the previous.
  #
  # @param workflow_name [String] name of the workflow to activate
  # @return [Workflows::Definition] the activated workflow
  # @raise [Workflows::InvalidDefinitionError] if workflow not found in registry
  # @raise [ActiveRecord::RecordInvalid] if save fails
  def activate_workflow(workflow_name)
    definition = Workflows::Registry.instance.find(workflow_name)
    raise Workflows::InvalidDefinitionError, "Unknown workflow: #{workflow_name}" unless definition

    return definition if active_workflow == workflow_name

    self.active_workflow = workflow_name
    save!
    definition
  end

  # Deactivates the current workflow on this session.
  #
  # @return [void]
  def deactivate_workflow
    return unless active_workflow.present?

    self.active_workflow = nil
    save!
  end
end
