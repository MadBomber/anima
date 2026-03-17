# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class Skills::RegistryTest < ActiveSupport::TestCase
  def setup
    Skills::Definition  # ensure autoloaded
  end

  # ─── Built-in skills ────────────────────────────────────────────────────

  test "reload! loads built-in skills from the skills/ directory" do
    registry = Skills::Registry.reload!

    assert registry.any?
  end

  test "built-in gh-issue skill loads correctly" do
    registry = Skills::Registry.reload!
    skill = registry.find("gh-issue")

    assert_not_nil skill
    assert_equal "gh-issue", skill.name
    assert_not_empty skill.description
  end

  test "catalog returns hash of name => description" do
    registry = Skills::Registry.reload!

    catalog = registry.catalog
    assert_kind_of Hash, catalog
    assert catalog.all? { |k, v| k.is_a?(String) && v.is_a?(String) }
  end

  test "available_names returns array of registered skill names" do
    registry = Skills::Registry.reload!

    assert_kind_of Array, registry.available_names
    assert_includes registry.available_names, "gh-issue"
  end

  test "size returns count of registered skills" do
    registry = Skills::Registry.reload!

    assert registry.size > 0
  end

  test "find returns nil for unknown skill" do
    registry = Skills::Registry.reload!

    assert_nil registry.find("no-such-skill")
  end

  # ─── Custom directory — flat file ───────────────────────────────────────

  test "load_directory loads flat .md skills" do
    tmpdir = Dir.mktmpdir("skills_test_flat")
    File.write(File.join(tmpdir, "my-skill.md"), <<~MD)
      ---
      name: my-skill
      description: "Custom flat skill."
      ---
      You are a flat skill.
    MD

    registry = Skills::Registry.new
    registry.load_directory(tmpdir)

    assert registry.find("my-skill")
    assert_equal "Custom flat skill.", registry.find("my-skill").description
  ensure
    FileUtils.remove_entry(tmpdir)
  end

  # ─── Custom directory — subdirectory SKILL.md format ───────────────────

  test "load_directory loads SKILL.md from subdirectory" do
    tmpdir = Dir.mktmpdir("skills_test_dir")
    subdir = File.join(tmpdir, "my-subskill")
    FileUtils.mkdir_p(subdir)
    File.write(File.join(subdir, "SKILL.md"), <<~MD)
      ---
      name: my-subskill
      description: "Skill from subdirectory."
      ---
      You are a subdirectory skill.
    MD

    registry = Skills::Registry.new
    registry.load_directory(tmpdir)

    assert registry.find("my-subskill")
    assert_equal "Skill from subdirectory.", registry.find("my-subskill").description
  ensure
    FileUtils.remove_entry(tmpdir)
  end

  # ─── Error handling ─────────────────────────────────────────────────────

  test "load_directory skips invalid definition files with a warning" do
    tmpdir = Dir.mktmpdir("skills_test_invalid")
    File.write(File.join(tmpdir, "bad.md"), "no frontmatter")

    registry = Skills::Registry.new
    assert_nothing_raised { registry.load_directory(tmpdir) }
    assert_equal 0, registry.size
  ensure
    FileUtils.remove_entry(tmpdir)
  end

  test "load_directory ignores missing directory" do
    registry = Skills::Registry.new
    assert_nothing_raised { registry.load_directory("/nonexistent/path") }
    assert_equal 0, registry.size
  end

  test "any? returns false for empty registry" do
    registry = Skills::Registry.new

    assert_not registry.any?
  end
end
