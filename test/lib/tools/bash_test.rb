# frozen_string_literal: true

require "test_helper"

class Tools::BashTest < ActiveSupport::TestCase
  def setup
    @shell = ShellSession.new(session_id: 100)
    @tool = Tools::Bash.new(shell_session: @shell)
  end

  def teardown
    @shell.finalize if @shell.alive?
  end

  test "tool_name is bash" do
    assert_equal "bash", Tools::Bash.tool_name
  end

  test "call returns error for blank command" do
    result = @tool.call("command" => "")

    assert_kind_of Hash, result
    assert_match(/blank/i, result[:error])
  end

  test "call returns error for whitespace-only command" do
    result = @tool.call("command" => "   ")

    assert_kind_of Hash, result
    assert_match(/blank/i, result[:error])
  end

  test "call returns string result for successful command" do
    result = @tool.call("command" => "echo hello")

    assert_kind_of String, result
  end

  test "call output includes stdout content" do
    result = @tool.call("command" => "echo test_output")

    assert_includes result, "test_output"
  end

  test "call output includes exit_code" do
    result = @tool.call("command" => "true")

    assert_includes result, "exit_code: 0"
  end

  test "call output includes non-zero exit code for failing command" do
    result = @tool.call("command" => "false")

    assert_includes result, "exit_code:"
    assert_not_includes result, "exit_code: 0"
  end

  test "call omits stdout section when output is empty" do
    result = @tool.call("command" => "true")

    assert_not_includes result, "stdout:"
  end

  test "call includes stderr section when command writes to stderr" do
    result = @tool.call("command" => "echo err_msg 1>&2")

    assert_includes result, "stderr:"
    assert_includes result, "err_msg"
  end

  test "params_schema returns an object schema with command property" do
    schema = Tools::Bash.new.params_schema
    assert_equal "object", schema["type"]
    assert schema["properties"].key?("command")
  end
end
