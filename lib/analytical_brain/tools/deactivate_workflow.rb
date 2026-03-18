# frozen_string_literal: true

module AnalyticalBrain
  module Tools
    # Deactivates the current workflow on the main session.
    # The workflow's content is removed from the main agent's system prompt.
    class DeactivateWorkflow < ::Tools::Base
      def self.tool_name = "deactivate_workflow"

      description "Deactivate the current workflow when it is complete or no longer relevant."

      params type: "object", properties: {}, required: []

      # @param main_session [Session] the session to deactivate the workflow on
      def initialize(main_session:, **)
        @main_session = main_session
      end

      # @return [String] confirmation message
      def execute(**)
        previous = @main_session.active_workflow
        @main_session.deactivate_workflow
        previous ? "Deactivated workflow: #{previous}" : "No workflow was active"
      end
    end
  end
end
