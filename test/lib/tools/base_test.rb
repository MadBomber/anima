# frozen_string_literal: true

require "test_helper"

class Tools::BaseTest < ActiveSupport::TestCase
  test "tool_name raises NotImplementedError" do
    assert_raises(NotImplementedError) { Tools::Base.tool_name }
  end

  test "description raises NotImplementedError" do
    assert_raises(NotImplementedError) { Tools::Base.description }
  end

  test "input_schema raises NotImplementedError" do
    assert_raises(NotImplementedError) { Tools::Base.input_schema }
  end

  test "execute raises NotImplementedError" do
    assert_raises(NotImplementedError) { Tools::Base.new.execute({}) }
  end

  test "schema returns Anthropic tool format for a concrete subclass" do
    tool = Class.new(Tools::Base) do
      def self.tool_name = "echo"
      def self.description = "Echoes input"
      def self.input_schema = {type: "object", properties: {text: {type: "string"}}, required: ["text"]}
    end

    schema = tool.schema

    assert_equal "echo", schema[:name]
    assert_equal "Echoes input", schema[:description]
    assert_equal "object", schema[:input_schema][:type]
  end

  test "initialize accepts and discards arbitrary context keywords" do
    assert_nothing_raised { Tools::Base.new(shell_session: "anything", other: 123) }
  end
end
