# frozen_string_literal: true

module Tools
  # Abstract base class for all Anima tools. Subclasses are first-class
  # RubyLLM::Tool instances passed directly to chat.with_tool — no wrapper needed.
  #
  # Subclasses must implement:
  #   - +.tool_name+ — unique identifier (overrides ruby_llm's class-name derivation)
  #   - +description "..."+ — human-readable description (ruby_llm class macro)
  #   - +params(input_schema)+ — JSON Schema hash (ruby_llm class macro)
  #   - +#execute(**kwargs)+ — execution with symbol keyword arguments
  #
  # @abstract
  class Base < RubyLLM::Tool
    class << self
      # @return [String] unique tool identifier sent to the LLM.
      # Required because ruby_llm derives name from the class name,
      # which would produce e.g. "tools--bash" instead of "bash".
      def tool_name
        raise NotImplementedError, "#{self} must implement .tool_name"
      end
    end

    # Returns the subclass-defined tool_name, overriding ruby_llm's
    # class-name-derived default.
    #
    # @return [String]
    def name
      self.class.tool_name
    end

    # Builds the schema hash in the format expected by the Anthropic tools API.
    # Used by Tools::Registry#schemas and for testing.
    #
    # @return [Hash] with :name, :description, and :input_schema keys
    def schema
      {name: name, description: description, input_schema: params_schema}
    end

    # Accepts and discards context keywords so that the Registry can pass
    # shared dependencies (e.g. shell_session) to any tool uniformly.
    # Subclasses that need specific context should override with named kwargs.
    #
    # @return [void]
    def initialize(**) = nil
  end
end
