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

# Unit tests for LLM::Client that do NOT require a live LLM.
# Exercises private helpers and edge cases that the Ollama integration
# suite can't reach when Ollama is absent.
class LLM::ClientUnitTest < ActiveSupport::TestCase
  def setup
    @client = LLM::Client.new
    @session = Session.create!
  end

  # ── chat_with_tools early-exit ────────────────────────────────────────────

  test "chat_with_tools returns nil immediately for an empty message list" do
    registry = Tools::Registry.new
    result = @client.chat_with_tools([], registry: registry, session_id: nil)
    assert_nil result
  end

  # ── interrupted? ─────────────────────────────────────────────────────────

  test "interrupted? returns false when session_id is nil" do
    assert_equal false, @client.send(:interrupted?, nil)
  end

  test "interrupted? returns false when session has no interrupt requested" do
    assert_equal false, @client.send(:interrupted?, @session.id)
  end

  test "interrupted? returns true when session has interrupt_requested set" do
    @session.update_columns(interrupt_requested: true)
    assert_equal true, @client.send(:interrupted?, @session.id)
  end

  # ── clear_interrupt! ─────────────────────────────────────────────────────

  test "clear_interrupt! is a no-op when session_id is nil" do
    assert_nil @client.send(:clear_interrupt!, nil)
  end

  test "clear_interrupt! clears interrupt_requested on the session" do
    @session.update_columns(interrupt_requested: true)
    @client.send(:clear_interrupt!, @session.id)
    assert_equal false, @session.reload.interrupt_requested
  end

  # ── format_result ────────────────────────────────────────────────────────

  test "format_result converts a Hash to JSON" do
    result = @client.send(:format_result, {status: "ok", value: 42})
    assert_equal '{"status":"ok","value":42}', result
  end

  test "format_result returns non-Hash values as strings" do
    assert_equal "plain text", @client.send(:format_result, "plain text")
    assert_equal "123",        @client.send(:format_result, 123)
  end

  # ── result_success? ───────────────────────────────────────────────────────

  test "result_success? returns false when result is a Hash with an :error key" do
    assert_equal false, @client.send(:result_success?, {error: "something went wrong"})
  end

  test "result_success? returns true for a Hash without :error" do
    assert_equal true, @client.send(:result_success?, {output: "done"})
  end

  test "result_success? returns true for non-Hash results" do
    assert_equal true, @client.send(:result_success?, "ok")
    assert_equal true, @client.send(:result_success?, 42)
  end

  # ── message_content ───────────────────────────────────────────────────────

  test "message_content serialises Array content to JSON" do
    content = [{"type" => "text", "text" => "hello"}]
    assert_equal content.to_json, @client.send(:message_content, content)
  end

  test "message_content returns String content as-is" do
    assert_equal "hello world", @client.send(:message_content, "hello world")
  end

  # ── oauth_token? ─────────────────────────────────────────────────────────

  test "oauth_token? returns false when api key does not start with OAuth prefix" do
    RubyLLM.configure { |c| c.anthropic_api_key = "sk-ant-api-key-123" }
    assert_equal false, @client.send(:oauth_token?)
  end

  test "oauth_token? returns true when api key starts with OAuth prefix" do
    RubyLLM.configure { |c| c.anthropic_api_key = "#{LLM::Client::OAUTH_TOKEN_PREFIX}fake" }
    assert_equal true, @client.send(:oauth_token?)
  ensure
    RubyLLM.configure { |c| c.anthropic_api_key = "sk-ant-api-key-restore" }
  end

  # ── oauth_headers ─────────────────────────────────────────────────────────

  test "oauth_headers returns Authorization and anthropic-beta headers" do
    RubyLLM.configure { |c| c.anthropic_api_key = "#{LLM::Client::OAUTH_TOKEN_PREFIX}mytoken" }
    headers = @client.send(:oauth_headers)
    assert_equal "Bearer #{LLM::Client::OAUTH_TOKEN_PREFIX}mytoken", headers["Authorization"]
    assert_equal LLM::Client::OAUTH_BETA, headers["anthropic-beta"]
  ensure
    RubyLLM.configure { |c| c.anthropic_api_key = "sk-ant-api-key-restore" }
  end
end
