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
end
