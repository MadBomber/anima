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

  test "input_schema requires thoughts" do
    schema = Tools::Think.input_schema
    assert_includes schema[:required], "thoughts"
  end

  test "input_schema lists visibility as an enum with inner and aloud" do
    visibility = Tools::Think.input_schema.dig(:properties, :visibility)
    assert_includes visibility[:enum], "inner"
    assert_includes visibility[:enum], "aloud"
  end

  test "execute returns OK for valid thoughts" do
    result = @tool.execute({"thoughts" => "This is a complex problem."})
    assert_equal "OK", result
  end

  test "execute returns error hash for empty thoughts" do
    result = @tool.execute({"thoughts" => ""})
    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "execute returns error hash for whitespace-only thoughts" do
    result = @tool.execute({"thoughts" => "   "})
    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "execute returns OK when visibility is inner" do
    result = @tool.execute({"thoughts" => "thinking quietly", "visibility" => "inner"})
    assert_equal "OK", result
  end

  test "execute returns OK when visibility is aloud" do
    result = @tool.execute({"thoughts" => "narrating my approach", "visibility" => "aloud"})
    assert_equal "OK", result
  end

  test "schema is valid Anthropic tool format" do
    schema = Tools::Think.schema
    assert_equal "think", schema[:name]
    assert schema.key?(:description)
    assert schema.key?(:input_schema)
  end
end
