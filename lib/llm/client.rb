# frozen_string_literal: true

module LLM
  # LLM chat client backed by the ruby_llm gem.
  #
  # Manages the full tool-use loop: seeding chat history from the Event table,
  # dispatching tool calls via {Tools::Registry}, emitting {Events::ToolCall}
  # and {Events::ToolResponse} events, and enforcing interrupt + round limits.
  #
  # A fresh RubyLLM::Chat is created per {#chat_with_tools} call so history is
  # always reconstructed from the database (stateless design).
  #
  # @example Background job usage
  #   client = LLM::Client.new
  #   client.chat_with_tools(session.messages_for_llm, registry: registry, session_id: session.id)
  class Client
    # Synthetic result content used when a tool is skipped due to user interrupt.
    INTERRUPT_MESSAGE = "Stopped by user"

    # @return [String] the model identifier
    attr_reader :model

    # @return [Integer] maximum tokens in the response
    attr_reader :max_tokens

    # @param model [String] model identifier (default from Settings)
    # @param max_tokens [Integer] maximum response tokens (default from Settings)
    # @param logger [Logger, nil] optional logger for tool call tracing
    # @param provider [Symbol, nil] override the ruby_llm provider (e.g. +:ollama+);
    #   when set, +assume_model_exists+ is enabled so local/unlisted models are accepted
    def initialize(model: Anima::Settings.model, max_tokens: Anima::Settings.max_tokens, logger: nil, provider: nil)
      @model = model
      @max_tokens = max_tokens
      @logger = logger
      @provider = provider
    end

    # Runs the LLM tool-use loop on a full message history.
    #
    # Seeds a fresh RubyLLM::Chat with prior history, then calls +ask+ with
    # the final user message. Tool calls are dispatched through the registry and
    # emitted as events. Interrupts and max-round limits are enforced.
    #
    # @param messages [Array<Hash>] full message history ending with the pending
    #   user message (each with +:role+ and +:content+)
    # @param registry [Tools::Registry] available tools
    # @param session_id [Integer, nil] session ID for events; nil for phantom sessions
    # @param options [Hash] extra options; +:system+ sets the system prompt
    # @return [String, nil] the assistant's final text, or nil when interrupted
    def chat_with_tools(messages, registry:, session_id:, **options)
      return nil if messages.empty?

      round_count = 0
      current_tool_call = nil

      chat = build_chat(messages, options)
      register_tools(chat, registry, session_id)

      chat.on_tool_call do |tc|
        round_count += 1
        max = Anima::Settings.max_tool_rounds
        raise MaxRoundsExceeded, "Tool loop exceeded #{max} rounds" if round_count > max

        current_tool_call = tc

        if interrupted?(session_id)
          emit_interrupted_call(tc, session_id)
          raise InterruptRequested
        end

        log(:debug, "tool_call: #{tc.name}(#{tc.arguments.to_json})")
        Events::Bus.emit(Events::ToolCall.new(
          content: "Calling #{tc.name}", tool_name: tc.name,
          tool_input: tc.arguments, tool_use_id: tc.id, session_id: session_id
        ))
      end

      chat.on_tool_result do |result|
        tc = current_tool_call
        next unless tc

        result_content = format_result(result)
        log(:debug, "tool_result: #{tc.name} → #{result_content.to_s.truncate(200)}")

        Events::Bus.emit(Events::ToolResponse.new(
          content: result_content, tool_name: tc.name, tool_use_id: tc.id,
          success: result_success?(result),
          session_id: session_id
        ))
      end

      last_msg = messages.last
      response = chat.ask(message_content(last_msg[:content]))

      if interrupted?(session_id)
        clear_interrupt!(session_id)
        return nil
      end

      response.content.to_s

    rescue MaxRoundsExceeded => e
      "[Tool loop exceeded #{Anima::Settings.max_tool_rounds} rounds — halting]"
    rescue InterruptRequested
      clear_interrupt!(session_id)
      nil
    end

    private

    # Builds a seeded RubyLLM::Chat from message history (all but the last message).
    def build_chat(messages, options)
      chat_opts = {model: model}
      if @provider
        chat_opts[:provider] = @provider
        chat_opts[:assume_model_exists] = true
      end
      chat = RubyLLM.chat(**chat_opts)
      chat.with_params(max_tokens: @max_tokens) if @max_tokens
      chat.with_headers(oauth_headers) if oauth_token?
      chat.with_instructions(options[:system]) if options[:system]

      messages[0..-2].each { |msg| seed_message(chat, msg) }

      chat
    end

    # Adds a single message to the chat, wrapping array content in Content::Raw
    # so tool_use / tool_result blocks pass through Anthropic formatting unchanged.
    def seed_message(chat, msg)
      content = if msg[:content].is_a?(Array)
        RubyLLM::Content::Raw.new(msg[:content])
      else
        msg[:content].to_s
      end
      chat.add_message(role: msg[:role].to_sym, content: content)
    end

    # Wraps each tool from the registry as a lightweight ruby_llm-compatible
    # object and registers it with the chat.
    def register_tools(chat, registry, session_id)
      registry.tools.each_value do |tool|
        chat.with_tool(ToolWrapper.new(tool, registry, session_id))
      end
    end

    # Extracts string content from a message's content field.
    # Array content (e.g. mixed tool_use blocks) is serialised to JSON.
    def message_content(content)
      content.is_a?(Array) ? content.to_json : content.to_s
    end

    def interrupted?(session_id)
      return false unless session_id

      Session.where(id: session_id, interrupt_requested: true).exists?
    end

    def clear_interrupt!(session_id)
      return unless session_id

      Session.where(id: session_id).update_all(interrupt_requested: false)
    end

    def format_result(result)
      result.is_a?(Hash) ? result.to_json : result.to_s
    end

    def result_success?(result)
      !result.is_a?(Hash) || !result.key?(:error)
    end

    def emit_interrupted_call(tc, session_id)
      Events::Bus.emit(Events::ToolCall.new(
        content: "Skipped #{tc.name} (interrupted)", tool_name: tc.name,
        tool_input: tc.arguments, tool_use_id: tc.id, session_id: session_id
      ))
      Events::Bus.emit(Events::ToolResponse.new(
        content: INTERRUPT_MESSAGE, tool_name: tc.name, tool_use_id: tc.id,
        success: false, session_id: session_id
      ))
    end

    def log(level, message)
      @logger&.public_send(level, message)
    end

    def oauth_token?
      RubyLLM.config.anthropic_api_key.to_s.start_with?(Providers::Anthropic::TOKEN_PREFIX)
    end

    def oauth_headers
      key = RubyLLM.config.anthropic_api_key
      {
        "Authorization"  => "Bearer #{key}",
        "anthropic-beta" => Providers::Anthropic::OAUTH_BETA
      }
    end

    # Raised when the tool-loop exceeds the max_tool_rounds limit.
    class MaxRoundsExceeded < StandardError; end

    # Raised when a user interrupt is detected during tool execution.
    class InterruptRequested < StandardError; end

    # Lightweight ruby_llm-compatible wrapper around a {Tools::Base} subclass
    # or duck-typed tool instance.
    #
    # Exposes the interface ruby_llm needs to format tool schemas for the
    # Anthropic API (+name+, +description+, +params_schema+, +provider_params+,
    # +parameters+, +call+) while delegating execution to the {Tools::Registry}.
    class ToolWrapper
      attr_reader :name, :description, :provider_params, :parameters

      def initialize(tool, registry, session_id)
        @_tool = tool
        @_registry = registry
        @_session_id = session_id
        @name = tool.tool_name
        @description = tool.description
        @provider_params = {}
        @parameters = {}
      end

      # Returns the JSON Schema for this tool's input parameters, with string
      # keys as required by ruby_llm's Anthropic formatter.
      def params_schema
        RubyLLM::Utils.deep_stringify_keys(@_tool.input_schema)
      end

      # Executes the tool via the registry. Normalises args to string keys so
      # tool implementations receive the same format they always have.
      def call(args)
        input = (args || {}).transform_keys(&:to_s)
        @_registry.execute(@name, input)
      rescue => error
        Rails.logger.error("Tool #{@name} raised #{error.class}: #{error.message}")
        {error: "#{error.class}: #{error.message}"}
      end
    end
  end
end
