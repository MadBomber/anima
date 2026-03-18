# frozen_string_literal: true

module AnalyticalBrain
  module Tools
    # Terminal tool that signals the analytical brain has completed its work.
    # Call this when no changes are needed — the current session state is
    # already good.
    #
    # After this tool returns, the LLM responds with text (not another
    # tool call), naturally terminating the chat_with_tools loop.
    class EverythingIsReady < ::Tools::Base
      def self.tool_name = "everything_is_ready"

      description "Signal that no changes are needed. " \
        "Call this when the session name and active skills are already appropriate."

      params type: "object", properties: {}, required: []

      # @return [String] confirmation message
      def execute(**)
        "Acknowledged. No changes needed."
      end
    end
  end
end
