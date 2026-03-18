# frozen_string_literal: true

require "test_helper"

class Tools::BaseTest < ActiveSupport::TestCase
  test "tool_name raises NotImplementedError" do
    assert_raises(NotImplementedError) { Tools::Base.tool_name }
  end

  test "name instance method delegates to class tool_name" do
    tool = Class.new(Tools::Base) do
      def self.tool_name = "my_tool"
      description "A test tool"
      params type: "object", properties: {}, required: []
    end

    assert_equal "my_tool", tool.new.name
  end

  test "schema instance method returns Anthropic tool format for a concrete subclass" do
    tool_class = Class.new(Tools::Base) do
      def self.tool_name = "echo"
      description "Echoes input"
      params type: "object",
        properties: {text: {type: "string"}},
        required: ["text"]
    end

    schema = tool_class.new.schema

    assert_equal "echo", schema[:name]
    assert_equal "Echoes input", schema[:description]
    assert_equal "object", schema[:input_schema]["type"]
  end

  test "initialize accepts and discards arbitrary context keywords" do
    assert_nothing_raised { Tools::Base.new(shell_session: "anything", other: 123) }
  end
end
