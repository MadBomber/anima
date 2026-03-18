# frozen_string_literal: true

# Manages LLM context window assembly: which events fit in the token budget,
# how they're serialised into Anthropic wire-format messages, and viewport
# snapshot bookkeeping so clients know when old events leave context.
#
# Sub-agent sessions inherit parent context at the fork point: child events
# fill the budget first (newest-first), remaining budget draws from parent
# events created before the fork. The combined result is always chronological.
module Session::ContextWindow
  extend ActiveSupport::Concern

  # Inflate heuristic token estimates by this factor to guard against
  # under-counting (code blocks, JSON, special characters tokenise smaller
  # than 4 bytes/token). Actual API-returned token_count values are used
  # verbatim — only estimates are padded.
  ESTIMATE_SAFETY_FACTOR = 1.15

  # Maximum events loaded from DB when scanning for the context window.
  # Events average ~50+ tokens, so 3000 events × 50 tokens = 150K tokens —
  # far beyond any realistic budget. Prevents full-table scans on old sessions.
  MAX_SCAN_EVENTS = 3000


  # Returns the events currently visible in the LLM context window.
  # Walks events newest-first and includes them until the token budget
  # is exhausted. Events are full-size or excluded entirely.
  #
  # @param token_budget [Integer] maximum tokens to include (positive)
  # @param include_pending [Boolean] whether to include pending messages
  # @return [Array<Event>] chronologically ordered
  def viewport_events(token_budget: Anima::Settings.token_budget, include_pending: true)
    own_events = select_events(own_event_scope(include_pending), budget: token_budget)
    remaining  = token_budget - own_events.sum { |e| event_token_cost(e) }

    if sub_agent? && remaining > 0
      parent_budget = [(token_budget * Anima::Settings.sub_agent_parent_context_ratio).to_i, remaining].min
      parent_events = select_events(parent_event_scope(include_pending), budget: parent_budget)
      trim_trailing_tool_calls(parent_events) + own_events
    else
      own_events
    end
  end

  # Recalculates the viewport and returns IDs of events evicted since the
  # last snapshot. Updates the stored viewport_event_ids atomically.
  #
  # @return [Array<Integer>] IDs of events no longer in the viewport
  def recalculate_viewport!
    new_ids = viewport_events.map(&:id)
    old_ids = viewport_event_ids

    evicted = old_ids - new_ids
    update_column(:viewport_event_ids, new_ids) if old_ids != new_ids
    evicted
  end

  # Overwrites the viewport snapshot without computing evictions.
  # Used when transmitting a full viewport refresh to clients.
  #
  # @param ids [Array<Integer>] event IDs now in the viewport
  # @return [void]
  def snapshot_viewport!(ids)
    update_column(:viewport_event_ids, ids)
  end

  # Builds the message array expected by the Anthropic Messages API.
  # Pending messages are excluded — they haven't been delivered yet.
  #
  # @param token_budget [Integer] maximum tokens to include
  # @return [Array<Hash>] Anthropic Messages API format
  def messages_for_llm(token_budget: Anima::Settings.token_budget)
    assemble_messages(viewport_events(token_budget: token_budget, include_pending: false))
  end

  # Promotes all pending user messages to delivered status so they
  # appear in the next LLM context.
  #
  # @return [Integer] number of promoted messages
  def promote_pending_messages!
    promoted = 0
    events.where(event_type: "user_message", status: Event::PENDING_STATUS).find_each do |event|
      event.update!(status: nil, payload: event.payload.except("status"))
      promoted += 1
    end
    promoted
  end

  private

  # @return [ActiveRecord::Relation]
  def own_event_scope(include_pending)
    scope = events.context_events
    include_pending ? scope : scope.deliverable
  end

  # @return [ActiveRecord::Relation]
  def parent_event_scope(include_pending)
    scope = parent_session.events.context_events.where(created_at: ...created_at)
    include_pending ? scope : scope.deliverable
  end

  # Walks events newest-first, selecting until the token budget is exhausted.
  # Always includes at least the newest event even if it exceeds budget.
  #
  # @param scope [ActiveRecord::Relation]
  # @param budget [Integer]
  # @return [Array<Event>] chronologically ordered
  def select_events(scope, budget:)
    selected  = []
    remaining = budget

    scope.reorder(id: :desc).limit(MAX_SCAN_EVENTS).each do |event|
      cost = event_token_cost(event)
      break if cost > remaining && selected.any?

      selected  << event
      remaining -= cost
    end

    selected.reverse
  end

  # @return [Integer] token cost, using cached count or padded heuristic estimate
  def event_token_cost(event)
    if event.token_count > 0
      event.token_count
    else
      (event.estimate_tokens * ESTIMATE_SAFETY_FACTOR).ceil
    end
  end

  # Removes trailing tool_call events that lack matching tool_response.
  # Prevents orphaned tool_use blocks at the parent/child viewport boundary.
  def trim_trailing_tool_calls(event_list)
    event_list.pop while event_list.last&.event_type == "tool_call"
    event_list
  end

  # Converts a chronological list of events into Anthropic wire-format messages.
  # Consecutive tool_call events are grouped into one assistant message;
  # consecutive tool_response events are grouped into one user message.
  #
  # @param events [Array<Event>]
  # @return [Array<Hash>]
  def assemble_messages(events)
    events.each_with_object([]) do |event, messages|
      case event.event_type
      when "user_message"
        content = "#{format_event_time(event.timestamp)}\n#{event.payload["content"]}"
        messages << {role: "user", content: content}
      when "agent_message"
        messages << {role: "assistant", content: event.payload["content"].to_s}
      when "tool_call"
        append_grouped_block(messages, "assistant", tool_use_block(event.payload))
      when "tool_response"
        append_grouped_block(messages, "user", tool_result_block(event.payload))
      when "system_message"
        messages << {role: "user", content: "[system] #{event.payload["content"]}"}
      end
    end
  end

  # Groups consecutive tool blocks into a single message of the given role.
  def append_grouped_block(messages, role, block)
    prev = messages.last
    if prev&.dig(:role) == role && prev[:content].is_a?(Array)
      prev[:content] << block
    else
      messages << {role: role, content: [block]}
    end
  end

  def tool_use_block(payload)
    {
      type:  "tool_use",
      id:    payload["tool_use_id"],
      name:  payload["tool_name"],
      input: payload["tool_input"] || {}
    }
  end

  def tool_result_block(payload)
    {
      type:        "tool_result",
      tool_use_id: payload["tool_use_id"],
      content:     payload["content"].to_s
    }
  end

  # Formats a nanosecond timestamp as a compact time prefix for LLM context.
  #
  # @param timestamp_ns [Integer] nanoseconds since epoch
  # @return [String] e.g. "Sat Mar 14 09:51"
  def format_event_time(timestamp_ns)
    Time.at(timestamp_ns / 1_000_000_000.0).strftime("%a %b %-d %H:%M")
  end
end
