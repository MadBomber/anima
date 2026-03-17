# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class Workflows::RegistryTest < ActiveSupport::TestCase
  def setup
    Workflows::Definition  # ensure autoloaded
  end

  # ─── Registry interface ─────────────────────────────────────────────────

  test "catalog returns a Hash" do
    registry = Workflows::Registry.new

    assert_kind_of Hash, registry.catalog
  end

  test "catalog entries have String keys and values" do
    tmpdir = Dir.mktmpdir("workflows_catalog_test")
    File.write(File.join(tmpdir, "catalog-test.md"), <<~MD)
      ---
      name: catalog-test
      description: "Catalog test workflow."
      ---
      ## Step 1
      Do the thing.
    MD

    registry = Workflows::Registry.new
    registry.load_directory(tmpdir)

    catalog = registry.catalog
    assert catalog.all? { |k, v| k.is_a?(String) && v.is_a?(String) }
  ensure
    FileUtils.remove_entry(tmpdir)
  end

  test "available_names returns array of registered workflow names" do
    tmpdir = Dir.mktmpdir("workflows_names_test")
    File.write(File.join(tmpdir, "my-wf.md"), <<~MD)
      ---
      name: my-wf
      description: "Test."
      ---
      Step 1.
    MD

    registry = Workflows::Registry.new
    registry.load_directory(tmpdir)

    assert_includes registry.available_names, "my-wf"
  ensure
    FileUtils.remove_entry(tmpdir)
  end

  test "find returns nil for unknown workflow" do
    registry = Workflows::Registry.new

    assert_nil registry.find("no-such-workflow")
  end

  test "size returns 0 for empty registry" do
    registry = Workflows::Registry.new

    assert_equal 0, registry.size
  end

  # ─── Custom directory loading ────────────────────────────────────────────

  test "load_directory loads workflows from a temp directory" do
    tmpdir = Dir.mktmpdir("workflows_test")
    File.write(File.join(tmpdir, "my-workflow.md"), <<~MD)
      ---
      name: my-workflow
      description: "Custom test workflow."
      ---
      ## Step 1
      Do the thing.
    MD

    registry = Workflows::Registry.new
    registry.load_directory(tmpdir)

    assert registry.find("my-workflow")
    assert_equal "Custom test workflow.", registry.find("my-workflow").description
  ensure
    FileUtils.remove_entry(tmpdir)
  end

  test "load_directory skips invalid definition files with a warning" do
    tmpdir = Dir.mktmpdir("workflows_test_invalid")
    File.write(File.join(tmpdir, "bad.md"), "no frontmatter")

    registry = Workflows::Registry.new
    assert_nothing_raised { registry.load_directory(tmpdir) }
    assert_equal 0, registry.size
  ensure
    FileUtils.remove_entry(tmpdir)
  end

  test "load_directory ignores missing directory" do
    registry = Workflows::Registry.new
    assert_nothing_raised { registry.load_directory("/nonexistent/path") }
    assert_equal 0, registry.size
  end

  test "load_all returns self (chainable)" do
    registry = Workflows::Registry.new
    result = registry.load_all

    assert_same registry, result
  end

  test "any? returns false for empty registry" do
    registry = Workflows::Registry.new

    assert_not registry.any?
  end

  test "any? returns true after loading workflows" do
    tmpdir = Dir.mktmpdir("workflows_any_test")
    File.write(File.join(tmpdir, "present.md"), <<~MD)
      ---
      name: present
      description: "Present."
      ---
      Content.
    MD

    registry = Workflows::Registry.new
    registry.load_directory(tmpdir)

    assert registry.any?
  ensure
    FileUtils.remove_entry(tmpdir)
  end
end
