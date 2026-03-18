# frozen_string_literal: true

module Tools
  # Executes bash commands in a persistent {ShellSession}. Commands share
  # working directory, environment variables, and shell history within a
  # conversation. Output is truncated and timeouts are enforced by the
  # underlying session.
  #
  # @see ShellSession#run
  class Bash < Base
    def self.tool_name = "bash"

    description "Execute a bash command. Working directory and environment persist across calls within a conversation."

    params type: "object",
      properties: {
        command: {type: "string", description: "The bash command to execute"}
      },
      required: ["command"]

    # @param shell_session [ShellSession] persistent shell backing this tool
    def initialize(shell_session: nil, **)
      @shell_session = shell_session
    end

    # @param command [String] the bash command to run
    # @return [String] formatted output with stdout, stderr, and exit code
    # @return [Hash] with :error key on failure
    def execute(command:)
      cmd = command.to_s
      return {error: "Command cannot be blank"} if cmd.strip.empty?

      result = @shell_session.run(cmd)
      return result if result.key?(:error)

      format_result(result[:stdout], result[:stderr], result[:exit_code])
    end

    private

    def format_result(stdout, stderr, exit_code)
      parts = []
      parts << "stdout:\n#{stdout}" unless stdout.empty?
      parts << "stderr:\n#{stderr}" unless stderr.empty?
      parts << "exit_code: #{exit_code}"
      parts.join("\n\n")
    end
  end
end
