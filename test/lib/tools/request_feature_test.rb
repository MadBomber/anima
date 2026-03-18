# frozen_string_literal: true

require "test_helper"

class Tools::RequestFeatureTest < ActiveSupport::TestCase
  def setup
    @tool = Tools::RequestFeature.new
  end

  test "tool_name is request_feature" do
    assert_equal "request_feature", Tools::RequestFeature.tool_name
  end

  test "params_schema returns an object schema with title and description" do
    schema = @tool.params_schema
    assert_equal "object", schema["type"]
    assert schema["properties"].key?("title")
    assert schema["properties"].key?("description")
  end

  test "call returns error for blank title" do
    result = @tool.call("title" => "", "description" => "Some detail")

    assert_kind_of Hash, result
    assert_match(/blank/i, result[:error])
  end

  test "call returns error for blank description" do
    result = @tool.call("title" => "A feature", "description" => "")

    assert_kind_of Hash, result
    assert_match(/blank/i, result[:error])
  end

  test "call returns error when no repository can be resolved" do
    # Run from a tmp directory that has no git remote and no config.toml setting.
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        tool = Tools::RequestFeature.new
        # Patch settings_repo to return nil (no config.toml repo set).
        tool.define_singleton_method(:settings_repo) { nil }

        result = tool.call("title" => "Add feature X", "description" => "We need X because Y")

        assert_kind_of Hash, result
        assert_match(/repository/i, result[:error])
      end
    end
  end

  test "call invokes gh and returns formatted output" do
    tool = Tools::RequestFeature.new
    tool.define_singleton_method(:resolve_repo) { "owner/repo" }
    tool.define_singleton_method(:run_gh) { |_repo, _title, _description|
      "https://github.com/owner/repo/issues/42"
    }

    result = tool.call("title" => "Add feature X", "description" => "We need X")

    assert_kind_of String, result
    assert_includes result, "owner/repo/issues/42"
  end

  test "call includes error output when gh fails" do
    tool = Tools::RequestFeature.new
    tool.define_singleton_method(:resolve_repo) { "owner/repo" }
    tool.define_singleton_method(:run_gh) { |_repo, _title, _description|
      "Error: not authenticated\n\nexit_code: 1"
    }

    result = tool.call("title" => "Add feature", "description" => "Need it")

    assert_kind_of String, result
    assert_includes result, "not authenticated"
    assert_includes result, "exit_code: 1"
  end
end
