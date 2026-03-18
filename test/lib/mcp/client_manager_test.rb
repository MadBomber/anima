# frozen_string_literal: true

require "test_helper"

# Integration tests: Anima's ClientManager against a real in-process
# MCP stdio server. Verifies that Anima correctly registers tools in
# its registry with prefixed names, caches clients across calls, and
# isolates failures to the broken server only.
class Mcp::ClientManagerTest < ActiveSupport::TestCase
  MCP_SERVER_SCRIPT = Rails.root.join("test/fixtures/mcp_server.rb").to_s

  # ─── Config doubles ───────────────────────────────────────────────────────

  def stdio_config(name: "test-server")
    config_double(
      stdio: [{name: name, command: RbConfig.ruby, args: [MCP_SERVER_SCRIPT], env: {}}]
    )
  end

  def config_double(stdio: [], http: [])
    Struct.new(:http_servers, :stdio_servers, :warnings).new(http, stdio, [])
  end

  def teardown
    # Clear the process-level client cache so each test starts fresh.
    Mcp::ClientManager.stop_all
  end

  # ─── Tool registration ────────────────────────────────────────────────────

  test "register_tools registers all tools from the server with server-prefixed names" do
    registry = Tools::Registry.new
    Mcp::ClientManager.new(config: stdio_config).register_tools(registry)

    assert registry.registered?("test-server_echo"), "expected test-server_echo to be registered"
    assert registry.registered?("test-server_add"),  "expected test-server_add to be registered"
  end

  test "register_tools returns no warnings when all servers connect" do
    registry = Tools::Registry.new
    warnings = Mcp::ClientManager.new(config: stdio_config).register_tools(registry)

    assert_empty warnings
  end

  test "registered MCP tools are dispatchable through the registry" do
    registry = Tools::Registry.new
    Mcp::ClientManager.new(config: stdio_config).register_tools(registry)

    result = registry.execute("test-server_echo", {"message" => "hello"})

    assert_includes result.to_s, "hello"
  end

  # ─── Client caching ───────────────────────────────────────────────────────

  test "second call to register_tools reuses the cached client" do
    manager = Mcp::ClientManager.new(config: stdio_config)

    manager.register_tools(Tools::Registry.new)
    client_first_call = Mcp::ClientManager.instance_variable_get(:@clients)["test-server"]

    manager.register_tools(Tools::Registry.new)
    client_second_call = Mcp::ClientManager.instance_variable_get(:@clients)["test-server"]

    assert_same client_first_call, client_second_call,
      "expected the same RubyLLM::MCP::Client instance to be reused"
  end

  # ─── Fault isolation ─────────────────────────────────────────────────────

  test "a broken server adds a warning without blocking tools from other servers" do
    config = config_double(
      stdio: [
        {name: "bad",  command: "nonexistent-mcp-cmd-xyz", args: [], env: {}},
        {name: "good", command: RbConfig.ruby, args: [MCP_SERVER_SCRIPT], env: {}}
      ]
    )
    registry = Tools::Registry.new
    warnings = Mcp::ClientManager.new(config: config).register_tools(registry)

    assert warnings.any? { |w| w.include?("bad") },
      "expected a warning mentioning the bad server"
    assert registry.registered?("good_echo"),
      "expected tools from the good server to still be registered"
  end
end
