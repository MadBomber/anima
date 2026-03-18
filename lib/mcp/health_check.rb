# frozen_string_literal: true

require "timeout"
require "ruby_llm/mcp"

module Mcp
  # Probes an MCP server to verify connectivity and count available tools.
  # Used by the CLI +list+ command to show server health status.
  #
  # @example
  #   result = Mcp::HealthCheck.call(name: "sentry", url: "https://mcp.sentry.dev/mcp", transport: "http")
  #   result #=> { status: :connected, tools: 5 }
  class HealthCheck
    # Health check probe timeout in seconds. Balances responsiveness
    # (CLI shouldn't hang) vs. giving slow servers a fair chance.
    TIMEOUT = 5

    # @param server [Hash] interpolated server config with symbol keys
    #   (+:name+, +:url+/+:command+, and +:transport+)
    # @return [Hash] +{ status: :connected, tools: Integer }+ or
    #   +{ status: :failed, error: String }+
    def self.call(server)
      new(server).call
    end

    def initialize(server)
      @server = server
      @client = nil
    end

    def call
      Timeout.timeout(TIMEOUT) { check }
    rescue Timeout::Error
      {status: :failed, error: "connection timeout"}
    rescue KeyError => key_error
      {status: :failed, error: "missing credential #{key_error.message}"}
    rescue => error
      {status: :failed, error: error.message}
    ensure
      @client&.stop
    end

    private

    def check
      transport = @server[:transport]

      case transport
      when "http" then check_http
      when "stdio" then check_stdio
      else {status: :failed, error: "unknown transport '#{transport}'"}
      end
    end

    def check_http
      @client = RubyLLM::MCP::Client.new(
        name: @server[:name],
        transport_type: :sse,
        config: {url: @server[:url], headers: @server[:headers] || {}}
      )
      {status: :connected, tools: @client.tools.size}
    end

    def check_stdio
      @client = RubyLLM::MCP::Client.new(
        name: @server[:name],
        transport_type: :stdio,
        config: {
          command: @server[:command],
          args: @server[:args] || [],
          env: @server[:env] || {}
        }
      )
      {status: :connected, tools: @client.tools.size}
    end
  end
end
