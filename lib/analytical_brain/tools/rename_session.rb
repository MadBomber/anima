# frozen_string_literal: true

module AnalyticalBrain
  module Tools
    # Renames the main session with an emoji and short descriptive name.
    # Operates on the main session passed through the registry context,
    # not on the phantom analytical brain session.
    #
    # The analytical brain calls this when a conversation's topic becomes
    # clear or shifts significantly enough to warrant a new name.
    class RenameSession < ::Tools::Base
      def self.tool_name = "rename_session"

      description "Rename the conversation session. " \
        "Use one emoji followed by 1-3 descriptive words."

      params type: "object",
        properties: {
          emoji: {
            type: "string",
            description: "A single emoji representing the conversation topic"
          },
          name: {
            type: "string",
            description: "1-3 word descriptive name for the session"
          }
        },
        required: %w[emoji name]

      # @param main_session [Session] the session to rename
      def initialize(main_session:, **)
        @main_session = main_session
      end

      # @param emoji [String] single emoji for the session
      # @param name [String] 1-3 word descriptive name
      # @return [String] confirmation message
      # @return [Hash] with :error key on validation failure
      def execute(emoji:, name:)
        emoji = emoji.to_s.strip
        name = name.to_s.strip

        return {error: "Emoji cannot be blank"} if emoji.empty?
        return {error: "Name cannot be blank"} if name.empty?

        full_name = "#{emoji} #{name}".truncate(255)
        @main_session.update!(name: full_name)
        "Session renamed to: #{full_name}"
      end
    end
  end
end
