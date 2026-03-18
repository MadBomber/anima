# frozen_string_literal: true

require "test_helper"

# Integration tests: Anima's HealthCheck against a real in-process
# MCP stdio server. Verifies the connected/failed contract that the
# CLI list command depends on.
class Mcp::HealthCheckTest < ActiveSupport::TestCase
  MCP_SERVER_SCRIPT = Rails.root.join("test/fixtures/mcp_server.rb").to_s

  def stdio_server(overrides = {})
    {
      name:      "test-server",
      transport: "stdio",
      command:   RbConfig.ruby,
      args:      [MCP_SERVER_SCRIPT],
      env:       {}
    }.merge(overrides)
  end

  # ─── Working server ───────────────────────────────────────────────────────

  test "returns :connected and correct tool count for a working stdio server" do
    result = Mcp::HealthCheck.call(stdio_server)

    assert_equal :connected, result[:status]
    assert_equal 2, result[:tools]
  end

  # ─── Broken server ────────────────────────────────────────────────────────

  test "returns :failed when the command does not exist" do
    result = Mcp::HealthCheck.call(stdio_server(command: "nonexistent-mcp-server-xyz"))

    assert_equal :failed, result[:status]
    assert_kind_of String, result[:error]
  end

  # ─── Unknown transport ────────────────────────────────────────────────────

  test "returns :failed with a descriptive error for an unrecognised transport" do
    result = Mcp::HealthCheck.call(name: "x", transport: "grpc", url: "grpc://localhost")

    assert_equal :failed, result[:status]
    assert_includes result[:error], "grpc"
  end
end
