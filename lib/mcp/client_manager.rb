# frozen_string_literal: true

require "ruby_llm/mcp"

module Mcp
  # Manages MCP client connections and registers their tools with
  # {Tools::Registry}.
  #
  # Clients are cached at the class level so each configured server starts
  # exactly one connection per process. Subsequent {AgentLoop} invocations
  # reuse the live clients — stdio subprocesses are not re-spawned on every
  # LLM turn, and tool lists are served from the gem's built-in cache.
  #
  # Tools are prefixed with the server name (e.g. +myserver_read+) to
  # prevent collisions when multiple servers expose same-named tools.
  #
  # @example
  #   manager = Mcp::ClientManager.new
  #   manager.register_tools(registry)
  class ClientManager
    @clients = {}
    @mutex = Mutex.new

    class << self
      # Stops all cached clients and clears the cache. Called at process exit
      # to terminate stdio subprocesses cleanly.
      def stop_all
        @mutex.synchronize do
          @clients.each_value(&:stop)
          @clients.clear
        end
      end

      # Returns a cached client for the named server, building it on first call.
      # Thread-safe: concurrent AgentLoop jobs will not double-start a client.
      #
      # @param name [String] server name
      # @param transport_type [Symbol] +:sse+ or +:stdio+
      # @param config [Hash] transport config merged with +with_prefix: true+
      # @return [RubyLLM::MCP::Client]
      def fetch_client(name, transport_type, config)
        @mutex.synchronize do
          @clients[name] ||= RubyLLM::MCP::Client.new(
            name: name,
            transport_type: transport_type,
            config: config.merge(with_prefix: true)
          )
        end
      end
    end

    at_exit { ClientManager.stop_all }

    # @param config [Mcp::Config] injectable config for testing
    def initialize(config: Config.new(logger: Rails.logger))
      @config = config
    end

    # Connects to all configured MCP servers and registers their tools
    # in the given registry. Returns warnings for servers that failed
    # to load so the caller can surface them to the user.
    #
    # @param registry [Tools::Registry] the registry to add tools to
    # @return [Array<String>] warning messages for servers that failed
    def register_tools(registry)
      warnings = []
      register_transport_tools(@config.http_servers, registry, warnings) { |server| build_http_client(server) }
      register_transport_tools(@config.stdio_servers, registry, warnings) { |server| build_stdio_client(server) }
      @config.warnings + warnings
    end

    private

    # Iterates server configs, fetches (or reuses) a client for each via the
    # block, and registers the server's tools. Failures are logged and collected.
    #
    # @param servers [Array<Hash>] server configs from {Mcp::Config}
    # @param registry [Tools::Registry] registry to register tools in
    # @param warnings [Array<String>] collects failure messages
    # @yield [server] block that returns a {RubyLLM::MCP::Client} for the server
    def register_transport_tools(servers, registry, warnings)
      servers.each do |server|
        client = yield(server)
        register_server_tools(server[:name], client, registry)
      rescue => error
        message = "MCP: failed to load tools from #{server[:name]}: #{error.message}"
        Rails.logger.warn(message)
        warnings << message
      end
    end

    # Fetches tools from an MCP client and registers them with the registry.
    # {RubyLLM::MCP::Tool} instances are registered directly — they already
    # carry their adapter reference and are prefixed with the server name.
    # The gem caches the tool list on the client, so subsequent calls are free.
    #
    # @param server_name [String] server name (for log message only)
    # @param client [RubyLLM::MCP::Client] connected MCP client
    # @param registry [Tools::Registry] registry to register tools in
    def register_server_tools(server_name, client, registry)
      count = client.tools.each { |tool| registry.register(tool) }.size
      Rails.logger.info("MCP: registered #{count} tools from #{server_name}")
    end

    # @param server [Hash] server config with +:name+, +:url+, +:headers+
    # @return [RubyLLM::MCP::Client]
    def build_http_client(server)
      self.class.fetch_client(
        server[:name], :sse,
        {url: server[:url], headers: server[:headers] || {}}
      )
    end

    # @param server [Hash] server config with +:name+, +:command+, +:args+, +:env+
    # @return [RubyLLM::MCP::Client]
    def build_stdio_client(server)
      self.class.fetch_client(
        server[:name], :stdio,
        {command: server[:command], args: server[:args] || [], env: server[:env] || {}}
      )
    end
  end
end
