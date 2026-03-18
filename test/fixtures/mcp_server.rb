#!/usr/bin/env ruby
# frozen_string_literal: true

# Minimal MCP stdio server used by integration tests.
# Implements the 2024-11-05 protocol subset that RubyLLM::MCP::Client
# exercises: initialize handshake, tools/list, tools/call, and ping.
# Not a test of the gem — exists solely to give Anima a real server
# to integrate against.

require "json"

$stdout.sync = true
$stderr.sync = true

TOOLS = [
  {
    "name" => "echo",
    "description" => "Returns the input message unchanged.",
    "inputSchema" => {
      "type" => "object",
      "properties" => {
        "message" => {"type" => "string", "description" => "Text to echo"}
      },
      "required" => ["message"]
    }
  },
  {
    "name" => "add",
    "description" => "Adds two integers and returns the sum.",
    "inputSchema" => {
      "type" => "object",
      "properties" => {
        "a" => {"type" => "integer"},
        "b" => {"type" => "integer"}
      },
      "required" => ["a", "b"]
    }
  }
].freeze

def send_response(id, result)
  $stdout.puts JSON.generate({"jsonrpc" => "2.0", "id" => id, "result" => result})
end

$stdin.each_line do |line|
  line.strip!
  next if line.empty?

  begin
    msg = JSON.parse(line)
  rescue JSON::ParseError => e
    $stderr.puts "MCP server parse error: #{e.message}"
    next
  end

  method = msg["method"]
  id     = msg["id"]

  case method
  when "initialize"
    version = msg.dig("params", "protocolVersion") || "2024-11-05"
    send_response id, {
      "protocolVersion" => version,
      "capabilities"    => {"tools" => {}},
      "serverInfo"      => {"name" => "test-mcp-server", "version" => "0.0.1"}
    }

  when "ping"
    send_response id, {} if id

  when "tools/list"
    send_response id, {"tools" => TOOLS}

  when "tools/call"
    name = msg.dig("params", "name")
    args = msg.dig("params", "arguments") || {}

    case name
    when "echo"
      send_response id, {"content" => [{"type" => "text", "text" => args["message"].to_s}]}
    when "add"
      sum = args["a"].to_i + args["b"].to_i
      send_response id, {"content" => [{"type" => "text", "text" => sum.to_s}]}
    else
      send_response id, {
        "content" => [{"type" => "text", "text" => "unknown tool: #{name}"}],
        "isError"  => true
      }
    end

  when /\Anotifications\//
    # Notifications do not require a response.
  end
end
