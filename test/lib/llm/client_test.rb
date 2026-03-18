# frozen_string_literal: true

require "test_helper"

# Integration tests for LLM::Client using a local Ollama instance.
#
# These tests hit a real LLM (gpt-oss:latest via Ollama) — no mocks.
# Ollama must be running on localhost:11434 for these tests to pass.
# Skip the entire suite if Ollama is unreachable.
class LLM::ClientTest < ActiveSupport::TestCase
  OLLAMA_MODEL = "gpt-oss:latest"

  class RecordingSubscriber
    include Events::Subscriber

    attr_reader :received

    def initialize
      @received = []
      @mutex = Mutex.new
    end

    def emit(event)
      @mutex.synchronize { @received << event }
    end
  end

  # Cheap tool used to verify tool dispatch works end-to-end.
  class AddTool < Tools::Base
    def self.tool_name = "add"

    description "Add two integers and return the sum"

    params type: "object",
      properties: {
        a: {type: "integer", description: "First number"},
        b: {type: "integer", description: "Second number"}
      },
      required: ["a", "b"]

    def execute(a:, b:)
      (a.to_i + b.to_i).to_s
    end
  end

  def setup
    skip "Ollama not reachable — set OLLAMA_API_BASE or start Ollama" unless ollama_reachable?

    @registry = Tools::Registry.new
    @client   = LLM::Client.new(model: OLLAMA_MODEL, provider: :ollama)
  end

  # ── LLM integration tests ────────────────────────────────────────────────

  test "returns nil for empty message list" do
    result = @client.chat_with_tools([], registry: @registry, session_id: nil)
    assert_nil result
  end

  test "returns a non-empty string for a simple user message" do
    messages = [{role: "user", content: "Reply with exactly the word PONG and nothing else."}]
    result   = @client.chat_with_tools(messages, registry: @registry, session_id: nil)
    assert_kind_of String, result
    assert result.length > 0
  end

  test "honours system prompt" do
    messages = [{role: "user", content: "What is your name?"}]
    result   = @client.chat_with_tools(
      messages,
      registry: @registry,
      session_id: nil,
      system: "You are a robot named ZORP. Always refer to yourself as ZORP."
    )
    assert_kind_of String, result
    assert_match(/ZORP/i, result)
  end

  test "dispatches tool call and returns text response" do
    @registry.register(AddTool)

    messages = [{role: "user", content: "Use the add tool to compute 11 + 22. Return only the numeric result."}]
    result   = @client.chat_with_tools(messages, registry: @registry, session_id: nil)

    assert_kind_of String, result
    assert_match(/33/, result)
  end

  test "emits ToolCall and ToolResponse events during tool dispatch" do
    @registry.register(AddTool)

    subscriber = RecordingSubscriber.new
    Events::Bus.subscribe(subscriber)

    messages = [{role: "user", content: "Use the add tool to compute 5 + 6. Return only the number."}]
    @client.chat_with_tools(messages, registry: @registry, session_id: nil)

    Events::Bus.unsubscribe(subscriber)

    types = subscriber.received.map { |e| e.dig(:payload, :type) }

    assert types.include?("tool_call"),     "expected at least one tool_call event"
    assert types.include?("tool_response"), "expected at least one tool_response event"
    assert_equal "add", subscriber.received.find { |e| e.dig(:payload, :type) == "tool_call" }
                                          .dig(:payload, :tool_name)
  end

  test "works with session_id nil (phantom session)" do
    messages = [{role: "user", content: "Say YES."}]
    result   = @client.chat_with_tools(messages, registry: @registry, session_id: nil)
    assert_kind_of String, result
  end

  private

  def ollama_reachable?
    require "net/http"
    uri = URI.parse("http://localhost:11434/api/tags")
    Net::HTTP.get_response(uri).is_a?(Net::HTTPSuccess)
  rescue
    false
  end
end
