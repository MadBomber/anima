# frozen_string_literal: true

require "test_helper"
require "tempfile"

class Workflows::DefinitionTest < ActiveSupport::TestCase
  VALID_WORKFLOW = <<~MD
    ---
    name: test-workflow
    description: "A workflow for testing."
    ---

    ## Step 1
    Do the first thing.

    ## Step 2
    Do the second thing.
  MD

  def write_workflow(content)
    file = Tempfile.new(["workflow_test", ".md"])
    file.write(content)
    file.flush
    file
  end

  def setup
    Workflows::Definition
  end

  # ─── from_file ────────────────────────────────────────────────────────────

  test "from_file parses name, description, and content" do
    file = write_workflow(VALID_WORKFLOW)
    definition = Workflows::Definition.from_file(file.path)

    assert_equal "test-workflow", definition.name
    assert_equal "A workflow for testing.", definition.description
    assert_includes definition.content, "Step 1"
  ensure
    file.close; file.unlink
  end

  test "from_file stores source_path" do
    file = write_workflow(VALID_WORKFLOW)
    definition = Workflows::Definition.from_file(file.path)

    assert_equal file.path, definition.source_path
  ensure
    file.close; file.unlink
  end

  test "from_file strips whitespace from content" do
    file = write_workflow(VALID_WORKFLOW)
    definition = Workflows::Definition.from_file(file.path)

    assert_not definition.content.start_with?("\n")
    assert_not definition.content.end_with?("\n")
  ensure
    file.close; file.unlink
  end

  test "from_file raises InvalidDefinitionError for missing frontmatter" do
    file = write_workflow("No frontmatter here.")
    assert_raises(Workflows::InvalidDefinitionError) do
      Workflows::Definition.from_file(file.path)
    end
  ensure
    file.close; file.unlink
  end

  test "from_file raises InvalidDefinitionError when name is missing" do
    workflow = <<~MD
      ---
      description: "No name field."
      ---
      Content.
    MD
    file = write_workflow(workflow)
    assert_raises(Workflows::InvalidDefinitionError) do
      Workflows::Definition.from_file(file.path)
    end
  ensure
    file.close; file.unlink
  end

  test "from_file raises InvalidDefinitionError when description is missing" do
    workflow = <<~MD
      ---
      name: no-description
      ---
      Content.
    MD
    file = write_workflow(workflow)
    assert_raises(Workflows::InvalidDefinitionError) do
      Workflows::Definition.from_file(file.path)
    end
  ensure
    file.close; file.unlink
  end

  test "from_file raises InvalidDefinitionError for uppercase name" do
    workflow = <<~MD
      ---
      name: Invalid-Name
      description: "Has uppercase."
      ---
      Content.
    MD
    file = write_workflow(workflow)
    assert_raises(Workflows::InvalidDefinitionError) do
      Workflows::Definition.from_file(file.path)
    end
  ensure
    file.close; file.unlink
  end

  test "from_file raises InvalidDefinitionError for name with spaces" do
    workflow = <<~MD
      ---
      name: has spaces
      description: "Invalid."
      ---
      Content.
    MD
    file = write_workflow(workflow)
    assert_raises(Workflows::InvalidDefinitionError) do
      Workflows::Definition.from_file(file.path)
    end
  ensure
    file.close; file.unlink
  end

  test "from_file accepts names with hyphens and underscores" do
    %w[my-workflow my_workflow my-workflow_v2].each do |name|
      workflow = <<~MD
        ---
        name: #{name}
        description: "Valid name."
        ---
        Content.
      MD
      file = write_workflow(workflow)
      definition = Workflows::Definition.from_file(file.path)
      assert_equal name, definition.name
    ensure
      file.close; file.unlink
    end
  end
end
