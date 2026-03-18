# frozen_string_literal: true

module Tools
  # Wraps a single MCP server tool for use with {Tools::Registry} and
  # +RubyLLM::Chat#with_tool+. Registered as an instance (not a class) —
  # the Registry stores it directly since MCP tools carry their own client
  # reference and are effectively stateless from the LLM's perspective.
  #
  # Implements the interface expected by +RubyLLM::Chat#with_tool+:
  # - +#name+ — unique identifier (namespaced as <server>__<tool>)
  # - +#description+ — human-readable description from MCP server
  # - +#params_schema+ — JSON Schema with string keys
  # - +#provider_params+ — empty hash (no provider-specific params)
  # - +#parameters+ — empty hash
  # - +#call(args)+ — executes the tool (normalises to string keys for MCP)
  #
  # Tool names are namespaced as `<server_name>__<tool_name>` to prevent
  # collisions between servers and with built-in tools.
  #
  # @example
  #   wrapper = Tools::McpTool.new(
  #     server_name: "mythonix",
  #     mcp_client: client,
  #     mcp_tool: client.tools.first
  #   )
  #   wrapper.name  # => "mythonix__create_image"
  #   wrapper.call({"prompt" => "a red dragon"})
  class McpTool
    # Separator between server name and tool name in namespaced identifiers.
    NAMESPACE_SEPARATOR = "__"

    # @return [String] namespaced tool identifier (<server>__<tool>)
    attr_reader :name

    # Kept as an alias for compatibility with Registry (keyed by tool_name).
    alias_method :tool_name, :name

    # @return [Hash] no provider-specific parameters
    attr_reader :provider_params

    # @return [Hash] no additional parameters
    attr_reader :parameters

    # @param server_name [String] MCP server name from config
    # @param mcp_client [MCP::Client] the client instance for this server
    # @param mcp_tool [MCP::Client::Tool] tool metadata from the server
    def initialize(server_name:, mcp_client:, mcp_tool:)
      @name = "#{server_name}#{NAMESPACE_SEPARATOR}#{mcp_tool.name}"
      @mcp_client = mcp_client
      @mcp_tool = mcp_tool
      @provider_params = {}
      @parameters = {}
    end

    # @return [String] tool description from the MCP server
    def description
      @mcp_tool.description
    end

    # Returns the JSON Schema for this tool's input parameters with string keys,
    # as required by ruby_llm's Anthropic formatter.
    # @return [Hash] string-keyed JSON Schema
    def params_schema
      RubyLLM::Utils.deep_stringify_keys(@mcp_tool.input_schema)
    end

    # Dispatches the tool call. Normalises args to string keys since the MCP
    # protocol operates on string-keyed hashes, then delegates to +execute+.
    #
    # @param args [Hash] tool arguments (symbol or string keys)
    # @return [String] normalised tool output
    # @return [Hash] with :error key on failure
    def call(args)
      execute((args || {}).transform_keys(&:to_s))
    end

    # Calls the MCP server tool and normalizes the response.
    #
    # @param input [Hash] string-keyed tool input parameters from the LLM
    # @return [String] normalized tool output
    # @return [Hash] with :error key on failure
    def execute(input)
      response = @mcp_client.call_tool(tool: @mcp_tool, arguments: input)
      normalize_response(response)
    rescue MCP::Client::RequestHandlerError => error
      {error: "#{name}: #{error.message}"}
    end

    # Builds the schema hash expected by the Anthropic tools API.
    # @return [Hash] with :name, :description, and :input_schema keys
    def schema
      {name: name, description: description, input_schema: @mcp_tool.input_schema}
    end

    private

    # Extracts content from an MCP tool response (JSON-RPC envelope).
    # Checks the `isError` flag and routes accordingly.
    #
    # @param response [Hash] full JSON-RPC response from MCP client
    # @return [String] concatenated text content
    # @return [Hash] with :error key if the response indicates an error
    def normalize_response(response)
      result = response["result"] || response
      error = result["isError"]

      text = extract_text(result)
      error ? {error: "#{name}: #{text}"} : text
    end

    # Extracts human-readable text from MCP content blocks.
    # MCP responses contain an array of typed content blocks.
    #
    # @param result [Hash] MCP result containing "content" array
    # @return [String] concatenated text from all content blocks
    def extract_text(result)
      content = result["content"]

      return result.to_json unless content

      case content
      when Array
        content.filter_map { |block|
          case block["type"]
          when "text" then block["text"]
          when "image" then "[image: #{block["mimeType"]}]"
          else block.to_json
          end
        }.join("\n")
      when String
        content
      else
        content.to_json
      end
    end
  end
end
