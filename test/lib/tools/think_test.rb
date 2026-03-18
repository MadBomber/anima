# frozen_string_literal: true

require "test_helper"

class Tools::ThinkTest < ActiveSupport::TestCase
  def setup
    @tool = Tools::Think.new
  end

  test "tool_name is think" do
    assert_equal "think", Tools::Think.tool_name
  end

  test "description is defined and non-empty" do
    assert_not_empty Tools::Think.description
  end

  test "params_schema requires thoughts" do
    schema = Tools::Think.new.params_schema
    assert_includes schema["required"], "thoughts"
  end

  test "params_schema lists visibility as an enum with inner and aloud" do
    visibility = Tools::Think.new.params_schema.dig("properties", "visibility")
    assert_includes visibility["enum"], "inner"
    assert_includes visibility["enum"], "aloud"
  end

  test "call returns OK for valid thoughts" do
    result = @tool.call("thoughts" => "This is a complex problem.")
    assert_equal "OK", result
  end

  test "call returns error hash for empty thoughts" do
    result = @tool.call("thoughts" => "")
    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "call returns error hash for whitespace-only thoughts" do
    result = @tool.call("thoughts" => "   ")
    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "call returns OK when visibility is inner" do
    result = @tool.call("thoughts" => "thinking quietly", "visibility" => "inner")
    assert_equal "OK", result
  end

  test "call returns OK when visibility is aloud" do
    result = @tool.call("thoughts" => "narrating my approach", "visibility" => "aloud")
    assert_equal "OK", result
  end

  test "schema is valid Anthropic tool format" do
    schema = @tool.schema
    assert_equal "think", schema[:name]
    assert schema.key?(:description)
    assert schema.key?(:input_schema)
  end
end
