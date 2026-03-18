# frozen_string_literal: true

module AnalyticalBrain
  module Tools
    # Deactivates a domain knowledge skill on the main session.
    # The skill's content is removed from the main agent's system prompt.
    class DeactivateSkill < ::Tools::Base
      def self.tool_name = "deactivate_skill"

      description "Deactivate a skill that is no longer relevant. " \
        "The skill's content will be removed from the agent's system prompt."

      params type: "object",
        properties: {
          name: {
            type: "string",
            description: "Name of the skill to deactivate (from the currently active skills list)"
          }
        },
        required: %w[name]

      # @param main_session [Session] the session to deactivate the skill on
      def initialize(main_session:, **)
        @main_session = main_session
      end

      # @param name [String] skill name to deactivate
      # @return [String] confirmation message
      # @return [Hash] with :error key on validation failure
      def execute(name:)
        skill_name = name.to_s.strip
        return {error: "Skill name cannot be blank"} if skill_name.empty?

        @main_session.deactivate_skill(skill_name)
        "Deactivated skill: #{skill_name}"
      end
    end
  end
end
