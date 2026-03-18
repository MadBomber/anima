# frozen_string_literal: true

module Tools
  # Shared prompt fragments and spawn guards for tools that spawn sub-agent sessions.
  # Included by {SpawnSubagent} and {SpawnSpecialist} to avoid duplication.
  module SubagentPrompts
    RETURN_INSTRUCTION = "Complete the assigned task, then call the return_result tool with your deliverable. " \
      "Do not ask follow-up questions — work with the context you have."

    EXPECTED_DELIVERABLE_PREFIX = "Expected deliverable: "

    # Maximum session ancestry depth allowed when spawning a sub-agent.
    # Depth 0 = root session (main agent), depth 1 = direct sub-agent, etc.
    # Prevents runaway recursive spawning (A → B → A → ...) and combinatorial
    # explosion of nested sessions.
    MAX_SPAWN_DEPTH = 3

    # Returns how many ancestor sessions this session has (0 for a root session).
    # Short-circuits once the limit is reached to avoid walking long chains.
    #
    # @return [Integer]
    def ancestry_depth
      depth = 0
      current = @session
      while current.parent_session_id.present?
        depth += 1
        return depth if depth >= MAX_SPAWN_DEPTH
        current = current.parent_session
      end
      depth
    end

    # Returns an error hash if the current session is already at max spawn depth,
    # nil otherwise. Call at the top of execute to guard against deep nesting.
    #
    # @return [Hash{Symbol => String}, nil]
    def check_spawn_depth
      return unless ancestry_depth >= MAX_SPAWN_DEPTH

      {error: "Cannot spawn sub-agent: maximum nesting depth (#{MAX_SPAWN_DEPTH}) reached"}
    end
  end
end
