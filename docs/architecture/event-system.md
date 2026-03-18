---
tags:
  - architecture
  - events
---

# Event System

Anima's nervous system is a pub/sub event bus built on **Rails Structured Event Reporter** — a native Rails 8.1 feature for structured event emission with typed payloads, subscriber patterns, and block-scoped context tagging.

## Five Event Types

Every meaningful agent action maps to one of five event types:

| Event | Purpose |
|---|---|
| `system_message` | Internal notifications — session start, errors, context changes |
| `user_message` | Input submitted by the human |
| `agent_message` | LLM response (text content from Nous) |
| `tool_call` | A tool invocation with its arguments |
| `tool_response` | The result returned by a tool |

These five types form a complete trace of every session. Every conversation is a sequence of these events, persisted in SQLite with full payloads.

## Two Transport Channels

Events flow through two channels simultaneously:

```
Event fires
    │
    ├── In-process (Rails Structured Event Reporter)
    │       └── Registered subscribers (Persister, LLM Instrumentation, etc.)
    │
    └── Over the wire (Action Cable WebSocket)
            └── TUI clients subscribed to session_<id>
```

**In-process** subscribers react synchronously within the same Ruby process. The `Persister` subscriber writes every event to SQLite. Other subscribers handle instrumentation, analytical brain triggering, and message collection.

**Over-the-wire** delivery happens via `Event::Broadcasting` callbacks — `after_create_commit` and `after_update_commit` hooks on the `Event` model that broadcast the event payload plus metadata (action type, viewport evictions) to all connected TUI clients via Action Cable.

## Subscribers

Subscribers implement the `Events::Subscriber` interface — a single `#emit(event)` method receiving a hash with `:name`, `:payload`, and `:timestamp` keys.

Registered at boot in `config/initializers/event_subscribers.rb`:

| Subscriber | Role |
|---|---|
| `Events::Subscribers::Persister` | Writes every event to the `events` table |
| `Events::Subscribers::MessageCollector` | Collects messages for in-memory context |
| `LLM::InstrumentationSubscriber` | Logs LLM call metrics per completion |

## Viewport Eviction Notifications

When events are assembled into a viewport, older events may fall outside the token budget — they're **evicted** from the current view (but never deleted from SQLite). When a new event is broadcast to TUI clients, the payload includes the IDs of any events that were evicted:

```json
{
  "type": "agent_message",
  "content": "...",
  "id": 99,
  "action": "create",
  "evicted_event_ids": [12, 13, 14]
}
```

TUI clients use this to remove evicted messages from their display, keeping the view consistent with what the LLM actually sees.

## LLM Instrumentation

A separate `ActiveSupport::Notifications` subscription on `complete_chat.ruby_llm` logs a structured line per LLM completion:

```
[LLM] agent session=42 model=claude-opus-4-6 in=1234 out=567 312ms
[LLM] analytical_brain session=42 model=claude-haiku-4-5 in=456 think=89 out=123 88ms
[LLM] agent session=7 model=claude-opus-4-6 in=800 cache_hit=400 out=210 201ms
```

Fields: context label, session ID (if present), model, input tokens, cache hit/write tokens (if non-zero), thinking tokens (if non-zero), output tokens, duration.

## Adding a Subscriber

```ruby
class MySubscriber
  include Events::Subscriber

  def emit(event)
    name    = event[:name]       # e.g., "anima.tool_call"
    payload = event[:payload]    # event-type-specific hash
    ts      = event[:timestamp]  # nanosecond integer

    # react to the event...
  end
end

# Register in config/initializers/event_subscribers.rb:
Events::Bus.subscribe(MySubscriber.new)
```

Each subscriber is independent — failures in one don't affect others.
