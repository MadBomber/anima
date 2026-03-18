# frozen_string_literal: true

module AnalyticalBrain
  module Tools
    # Creates a goal on the main session. Root goals represent high-level
    # objectives (semantic episodes); sub-goals are TODO-style steps within
    # a root goal. The two-level hierarchy is enforced by the Goal model.
    class SetGoal < ::Tools::Base
      def self.tool_name = "set_goal"

      description "Create a goal on the main session. " \
        "Omit parent_goal_id for a root goal, or provide it to create a sub-goal (TODO item)."

      params type: "object",
        properties: {
          description: {
            type: "string",
            description: "What needs to be accomplished (1-2 sentences)"
          },
          parent_goal_id: {
            type: "integer",
            description: "ID of the parent goal (omit for root goals)"
          }
        },
        required: %w[description]

      # @param main_session [Session] the session to create the goal on
      def initialize(main_session:, **)
        @main_session = main_session
      end

      # @param description [String] goal description
      # @param parent_goal_id [Integer, nil] parent goal ID for sub-goals
      # @return [String] confirmation with goal ID
      # @return [Hash] with :error key on validation failure
      def execute(description:, parent_goal_id: nil)
        description = description.to_s.strip
        return {error: "Description cannot be blank"} if description.empty?

        goal = @main_session.goals.create!(
          description: description,
          parent_goal_id: parent_goal_id
        )
        format_confirmation(goal)
      rescue ActiveRecord::RecordInvalid => error
        {error: error.record.errors.full_messages.join(", ")}
      end

      private

      def format_confirmation(goal)
        prefix = goal.parent_goal_id ? "Sub-goal" : "Goal"
        "#{prefix} created: #{goal.description} (id: #{goal.id})"
      end
    end
  end
end
