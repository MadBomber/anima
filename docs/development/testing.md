---
tags:
  - development
  - testing
---

# Running Tests

Anima uses **Minitest** with the standard Rails test helpers.

## Run the Full Suite

```bash
bundle exec rails test
```

## Run a Specific File

```bash
bundle exec rails test test/models/session_test.rb
```

## Run a Specific Test

```bash
bundle exec rails test test/models/session_test.rb:42
```

(Replace `42` with the line number of the test.)

## Test Directory Structure

```
test/
├── test_helper.rb              — Global test configuration
├── models/                     — Model unit tests
├── jobs/                       — Job unit tests
├── channels/                   — ActionCable channel tests
├── lib/                        — Library unit tests
│   ├── tools/                  — Tool tests
│   ├── events/                 — Event system tests
│   ├── mcp/                    — MCP integration tests
│   └── llm/                    — LLM client tests
└── integration/                — Integration tests
```

## Test Coverage

SimpleCov tracks coverage. A coverage report is generated at `coverage/index.html` after running the suite:

```bash
bundle exec rails test && open coverage/index.html
```

## Testing Tools

Each tool in `lib/tools/` has an `execute` method designed for isolation testing — no Rails dependencies, no side effects beyond the operation itself. Tool tests can call `execute` directly with controlled inputs:

```ruby
test "read returns file content" do
  tool = Tools::Read.new
  result = tool.execute(path: "test/fixtures/sample.txt")
  assert_equal "sample content\n", result
end
```

## WebMock

`webmock` is included for stubbing HTTP requests in tool and MCP tests:

```ruby
stub_request(:get, "https://example.com/api")
  .to_return(body: "response body", status: 200)
```

## Testing Event Subscribers

Event subscribers can be tested by constructing synthetic event hashes and calling `emit` directly:

```ruby
test "persister saves event to database" do
  subscriber = Events::Subscribers::Persister.new
  event = {
    name: "anima.user_message",
    payload: { type: "user_message", content: "hello", session_id: sessions(:default).id },
    timestamp: Time.now.to_i
  }
  assert_difference "Event.count" do
    subscriber.emit(event)
  end
end
```
