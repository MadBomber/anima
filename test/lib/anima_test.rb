# frozen_string_literal: true

require "test_helper"

class AnimaTest < ActiveSupport::TestCase
  test "gem_root returns a Pathname pointing to the gem root" do
    root = Anima.gem_root

    assert_instance_of Pathname, root
    assert root.exist?
    assert root.join("Gemfile").exist?
  end

  test "gem_root is memoized" do
    assert_same Anima.gem_root, Anima.gem_root
  end

  test "Anima::Error is a StandardError subclass" do
    assert Anima::Error.ancestors.include?(StandardError)
  end

  test "boot_rails! is a no-op when Rails is already loaded" do
    # Rails is already loaded in the test environment — must not raise
    assert_nothing_raised { Anima.boot_rails! }
  end

  test "VERSION constant is a non-empty string" do
    assert_kind_of String, Anima::VERSION
    assert_not_empty Anima::VERSION
  end
end

class Anima::SettingsTest < ActiveSupport::TestCase
  def setup
    @original_path = Anima::Settings.config_path
  end

  def teardown
    Anima::Settings.config_path = @original_path
  end

  test "reset! restores config_path to the default" do
    Anima::Settings.config_path = "/tmp/custom.toml"
    Anima::Settings.reset!

    assert_equal Anima::Settings::DEFAULT_PATH, Anima::Settings.config_path
  end

  test "raises MissingConfigError when config file does not exist" do
    Anima::Settings.config_path = "/nonexistent/path/config.toml"

    assert_raises(Anima::Settings::MissingConfigError) { Anima::Settings.model }
  end

  test "raises MissingSettingError when requested key is absent from config" do
    overridden = Tempfile.new(["settings_missing_key_test", ".toml"])
    begin
      overridden.write("[llm]\n")
      overridden.flush
      Anima::Settings.config_path = overridden.path

      assert_raises(Anima::Settings::MissingSettingError) { Anima::Settings.model }
    ensure
      overridden.close; overridden.unlink
    end
  end

  test "validate_config! error message names the invalid key" do
    overridden = Tempfile.new(["settings_invalid_key_test", ".toml"])
    begin
      # Write a config with max_tokens = 0 (not a positive integer)
      overridden.write(valid_toml_except("max_tokens", "0"))
      overridden.flush
      Anima::Settings.config_path = overridden.path

      error = assert_raises(Anima::Settings::MissingSettingError) { Anima::Settings.model }
      assert_match(/max_tokens/, error.message)
      assert_match(/positive integer/, error.message)
    ensure
      overridden.close; overridden.unlink
    end
  end

  test "validate_config! rejects empty model string" do
    overridden = Tempfile.new(["settings_empty_model_test", ".toml"])
    begin
      overridden.write(valid_toml_except("model", '""'))
      overridden.flush
      Anima::Settings.config_path = overridden.path

      error = assert_raises(Anima::Settings::MissingSettingError) { Anima::Settings.model }
      assert_match(/model/, error.message)
      assert_match(/non-empty string/, error.message)
    ensure
      overridden.close; overridden.unlink
    end
  end

  test "validate_config! rejects parent_context_ratio outside 0..1" do
    overridden = Tempfile.new(["settings_ratio_test", ".toml"])
    begin
      overridden.write(valid_toml_except("parent_context_ratio", "1.5"))
      overridden.flush
      Anima::Settings.config_path = overridden.path

      error = assert_raises(Anima::Settings::MissingSettingError) { Anima::Settings.model }
      assert_match(/parent_context_ratio/, error.message)
    ensure
      overridden.close; overridden.unlink
    end
  end

  test "config is re-parsed when the file mtime changes" do
    overridden = Tempfile.new(["settings_hotreload_test", ".toml"])
    begin
      overridden.write(minimal_valid_toml(model: "claude-sonnet-4-6"))
      overridden.flush
      Anima::Settings.config_path = overridden.path

      assert_equal "claude-sonnet-4-6", Anima::Settings.model

      # Rewrite with a different model value and advance the mtime
      overridden.rewind
      overridden.truncate(0)
      overridden.write(minimal_valid_toml(model: "claude-haiku-4-5"))
      overridden.flush
      future = Time.now + 2
      File.utime(future, future, overridden.path)

      assert_equal "claude-haiku-4-5", Anima::Settings.model
    ensure
      overridden.close; overridden.unlink
    end
  end

  test "load_builtin_workflows returns true when key is absent from config" do
    # The test config has no [workflows] section → defaults to true
    assert_equal true, Anima::Settings.load_builtin_workflows
  end

  test "load_builtin_workflows returns false when load_builtin = false in config" do
    overridden = Tempfile.new(["settings_workflows_test", ".toml"])
    begin
      overridden.write(minimal_valid_toml + "\n[workflows]\nload_builtin = false\n")
      overridden.flush
      Anima::Settings.config_path = overridden.path

      assert_equal false, Anima::Settings.load_builtin_workflows
    ensure
      overridden.close; overridden.unlink
    end
  end

  test "load_builtin_workflows returns true when load_builtin = true in config" do
    overridden = Tempfile.new(["settings_workflows_true_test", ".toml"])
    begin
      overridden.write(minimal_valid_toml + "\n[workflows]\nload_builtin = true\n")
      overridden.flush
      Anima::Settings.config_path = overridden.path

      assert_equal true, Anima::Settings.load_builtin_workflows
    ensure
      overridden.close; overridden.unlink
    end
  end

  private

  # Returns a minimal valid TOML string. Pass model: to override the model key.
  def minimal_valid_toml(model: "claude-sonnet-4-6")
    <<~TOML
      [llm]
      model = "#{model}"
      fast_model = "claude-haiku-4-5"
      max_tokens = 8192
      max_tool_rounds = 500
      token_budget = 190000

      [timeouts]
      api = 300
      command = 30
      mcp_response = 60
      web_request = 10

      [shell]
      max_output_bytes = 100000

      [tools]
      max_file_size = 10485760
      max_read_lines = 2000
      max_read_bytes = 50000
      max_web_response_bytes = 100000

      [environment]
      project_files = ["CLAUDE.md"]
      project_files_max_depth = 3

      [github]
      repo = "test/anima"
      label = "anima-wants"

      [paths]
      soul = "/tmp/soul.md"

      [session]
      name_generation_interval = 30

      [analytical_brain]
      max_tokens = 4096
      blocking_on_user_message = true
      blocking_on_agent_message = false
      event_window = 20

      [sub_agent]
      parent_context_ratio = 0.5
    TOML
  end

  # Returns a valid TOML string with one key overridden to an invalid value.
  def valid_toml_except(key, value)
    minimal_valid_toml.gsub(/^#{Regexp.escape(key)} = .*$/, "#{key} = #{value}")
  end
end
