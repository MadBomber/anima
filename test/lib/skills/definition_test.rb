# frozen_string_literal: true

require "test_helper"
require "tempfile"

class Skills::DefinitionTest < ActiveSupport::TestCase
  VALID_SKILL = <<~MD
    ---
    name: test-skill
    description: "A skill for testing purposes."
    ---

    # Test Skill

    This skill helps with testing.
  MD

  def write_skill(content)
    file = Tempfile.new(["skill_test", ".md"])
    file.write(content)
    file.flush
    file
  end

  def setup
    # Skills::InvalidDefinitionError lives in definition.rb alongside Definition.
    # Reference Skills::Definition to ensure the file is autoloaded before
    # any test that asserts on the error class.
    Skills::Definition
  end

  # ─── from_file ───────────────────────────────────────────────────────────

  test "from_file parses name, description, and content" do
    file = write_skill(VALID_SKILL)
    definition = Skills::Definition.from_file(file.path)

    assert_equal "test-skill", definition.name
    assert_equal "A skill for testing purposes.", definition.description
    assert_includes definition.content, "Test Skill"
  ensure
    file.close; file.unlink
  end

  test "from_file stores the source_path" do
    file = write_skill(VALID_SKILL)
    definition = Skills::Definition.from_file(file.path)

    assert_equal file.path, definition.source_path
  ensure
    file.close; file.unlink
  end

  test "from_file strips whitespace from name and description" do
    skill = <<~MD
      ---
      name:   padded-skill
      description:  "  Has surrounding spaces.  "
      ---
      Content here.
    MD
    file = write_skill(skill)
    definition = Skills::Definition.from_file(file.path)

    assert_equal "padded-skill", definition.name
    assert_equal "Has surrounding spaces.", definition.description
  ensure
    file.close; file.unlink
  end

  test "from_file strips whitespace from content body" do
    file = write_skill(VALID_SKILL)
    definition = Skills::Definition.from_file(file.path)

    assert_not definition.content.start_with?("\n")
    assert_not definition.content.end_with?("\n")
  ensure
    file.close; file.unlink
  end

  test "from_file raises InvalidDefinitionError for missing frontmatter" do
    file = write_skill("No frontmatter here, just content.")
    assert_raises(Skills::InvalidDefinitionError) do
      Skills::Definition.from_file(file.path)
    end
  ensure
    file.close; file.unlink
  end

  test "from_file raises InvalidDefinitionError when name is missing" do
    skill = <<~MD
      ---
      description: "Missing name field."
      ---
      Content.
    MD
    file = write_skill(skill)
    assert_raises(Skills::InvalidDefinitionError) do
      Skills::Definition.from_file(file.path)
    end
  ensure
    file.close; file.unlink
  end

  test "from_file raises InvalidDefinitionError when description is missing" do
    skill = <<~MD
      ---
      name: no-description
      ---
      Content.
    MD
    file = write_skill(skill)
    assert_raises(Skills::InvalidDefinitionError) do
      Skills::Definition.from_file(file.path)
    end
  ensure
    file.close; file.unlink
  end

  test "from_file raises InvalidDefinitionError for invalid name format" do
    skill = <<~MD
      ---
      name: Invalid Name With Spaces
      description: "Has uppercase and spaces."
      ---
      Content.
    MD
    file = write_skill(skill)
    assert_raises(Skills::InvalidDefinitionError) do
      Skills::Definition.from_file(file.path)
    end
  ensure
    file.close; file.unlink
  end

  test "from_file accepts names with hyphens and underscores" do
    %w[my-skill my_skill my-skill_v2 a1b2c3].each do |name|
      skill = <<~MD
        ---
        name: #{name}
        description: "Valid name format."
        ---
        Content.
      MD
      file = write_skill(skill)
      definition = Skills::Definition.from_file(file.path)
      assert_equal name, definition.name
    ensure
      file.close; file.unlink
    end
  end

  # ─── Built-in skill files ────────────────────────────────────────────────

  test "gh-issue built-in skill loads correctly" do
    path = File.join(Skills::Registry::BUILTIN_DIR, "gh-issue.md")
    skip "gh-issue.md not found" unless File.exist?(path)

    definition = Skills::Definition.from_file(path)

    assert_equal "gh-issue", definition.name
    assert_not_empty definition.description
    assert_not_empty definition.content
  end
end
