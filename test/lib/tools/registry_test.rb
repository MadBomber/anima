# frozen_string_literal: true

require "test_helper"

class Tools::RegistryTest < ActiveSupport::TestCase
  # Minimal concrete tool for use in registry tests.
  class EchoTool < Tools::Base
    def self.tool_name = "echo"
    def self.description = "Echoes input back"
    def self.input_schema = {type: "object", properties: {text: {type: "string"}}, required: ["text"]}

    def execute(input)
      input["text"].to_s
    end
  end

  class UpperTool < Tools::Base
    def self.tool_name = "upper"
    def self.description = "Uppercases input"
    def self.input_schema = {type: "object", properties: {text: {type: "string"}}, required: ["text"]}

    def execute(input)
      input["text"].to_s.upcase
    end
  end

  def setup
    @registry = Tools::Registry.new
  end

  test "register adds a tool by its tool_name" do
    @registry.register(EchoTool)
    assert @registry.registered?("echo")
  end

  test "registered? returns false for unknown tools" do
    assert_not @registry.registered?("nonexistent")
  end

  test "any? returns false on empty registry" do
    assert_not @registry.any?
  end

  test "any? returns true after registration" do
    @registry.register(EchoTool)
    assert @registry.any?
  end

  test "schemas returns array with one schema per registered tool" do
    @registry.register(EchoTool)
    @registry.register(UpperTool)

    schemas = @registry.schemas

    assert_equal 2, schemas.size
    names = schemas.map { |s| s[:name] }
    assert_includes names, "echo"
    assert_includes names, "upper"
  end

  test "execute dispatches to the correct tool" do
    @registry.register(EchoTool)
    result = @registry.execute("echo", {"text" => "hello"})
    assert_equal "hello", result
  end

  test "execute instantiates tool classes with context" do
    context_tool = Class.new(Tools::Base) do
      def self.tool_name = "ctx"
      def self.description = "Context tool"
      def self.input_schema = {type: "object", properties: {}, required: []}

      def initialize(shell_session: nil, **)
        @shell_session = shell_session
      end

      def execute(_input)
        @shell_session ? "has context" : "no context"
      end
    end

    registry = Tools::Registry.new(context: {shell_session: "fake_session"})
    registry.register(context_tool)

    assert_equal "has context", registry.execute("ctx", {})
  end

  test "execute raises UnknownToolError for unregistered tool name" do
    assert_raises(Tools::UnknownToolError) do
      @registry.execute("nonexistent", {})
    end
  end

  test "execute works with duck-typed tool instances" do
    # McpTool-style instances carry their own state; registry calls them directly.
    # Simulate with a simple struct that matches the duck type.
    instance = Object.new
    instance.define_singleton_method(:tool_name) { "instance_tool" }
    instance.define_singleton_method(:schema) { {name: "instance_tool", description: "x", input_schema: {}} }
    instance.define_singleton_method(:execute) { |input| "instance:#{input["x"]}" }

    @registry.register(instance)
    result = @registry.execute("instance_tool", {"x" => "hello"})
    assert_equal "instance:hello", result
  end

  test "tools accessor exposes registered tools keyed by name" do
    @registry.register(EchoTool)
    assert_equal EchoTool, @registry.tools["echo"]
  end
end
