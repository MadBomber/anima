# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class Agents::RegistryTest < ActiveSupport::TestCase
  def setup
    Agents::Definition  # ensure autoloaded
  end

  # ─── Built-in agents ────────────────────────────────────────────────────

  test "reload! loads built-in agents from the agents/ directory" do
    registry = Agents::Registry.reload!

    assert registry.any?
  end

  test "built-in codebase-analyzer agent loads correctly" do
    registry = Agents::Registry.reload!
    agent = registry.get("codebase-analyzer")

    assert_not_nil agent
    assert_equal "codebase-analyzer", agent.name
    assert_not_empty agent.description
    assert_not_empty agent.prompt
  end

  test "catalog returns hash of name => description" do
    registry = Agents::Registry.reload!

    catalog = registry.catalog
    assert_kind_of Hash, catalog
    assert catalog.all? { |k, v| k.is_a?(String) && v.is_a?(String) }
  end

  test "names returns array of registered agent names" do
    registry = Agents::Registry.reload!

    assert_kind_of Array, registry.names
    assert_includes registry.names, "codebase-analyzer"
  end

  test "size returns count of registered agents" do
    registry = Agents::Registry.reload!

    assert registry.size > 0
  end

  test "get returns nil for unknown agent" do
    registry = Agents::Registry.reload!

    assert_nil registry.get("no-such-agent")
  end

  # ─── Custom directory loading ────────────────────────────────────────────

  test "load_directory loads agents from a temp directory" do
    tmpdir = Dir.mktmpdir("agents_test")
    File.write(File.join(tmpdir, "my-agent.md"), <<~MD)
      ---
      name: my-agent
      description: "Custom test agent."
      tools: read
      ---
      You are a custom agent.
    MD

    registry = Agents::Registry.new
    registry.load_directory(tmpdir)

    assert registry.get("my-agent")
    assert_equal "Custom test agent.", registry.get("my-agent").description
  ensure
    FileUtils.remove_entry(tmpdir)
  end

  test "load_directory skips invalid definition files with a warning" do
    tmpdir = Dir.mktmpdir("agents_test_invalid")
    File.write(File.join(tmpdir, "bad.md"), "no frontmatter")

    registry = Agents::Registry.new
    assert_nothing_raised { registry.load_directory(tmpdir) }
    assert_equal 0, registry.size
  ensure
    FileUtils.remove_entry(tmpdir)
  end

  test "load_directory ignores missing directory" do
    registry = Agents::Registry.new
    assert_nothing_raised { registry.load_directory("/nonexistent/path") }
    assert_equal 0, registry.size
  end

  # ─── Singleton instance ─────────────────────────────────────────────────

  test "instance returns a registry loaded with built-in agents" do
    # Force reload to clear memoized instance
    Agents::Registry.reload!

    # Now clear the memoized instance so .instance takes the lazy path
    Agents::Registry.instance_variable_set(:@instance, nil)
    registry = Agents::Registry.instance

    assert registry.any?
    assert registry.get("codebase-analyzer")
  end

  # ─── validate_tools! with unknown tools ─────────────────────────────────

  test "load_directory skips agent with unknown tools" do
    tmpdir = Dir.mktmpdir("agents_bad_tools")
    File.write(File.join(tmpdir, "bad-tools.md"), <<~MD)
      ---
      name: bad-tools
      description: "Uses unknown tools."
      tools: nonexistent_tool_xyz
      ---
      Prompt.
    MD

    registry = Agents::Registry.new
    assert_nothing_raised { registry.load_directory(tmpdir) }
    assert_equal 0, registry.size
  ensure
    FileUtils.remove_entry(tmpdir)
  end
end
