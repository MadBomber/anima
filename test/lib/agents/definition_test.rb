# frozen_string_literal: true

require "test_helper"
require "tempfile"

class Agents::DefinitionTest < ActiveSupport::TestCase
  VALID_AGENT = <<~MD
    ---
    name: test-agent
    description: "A test agent for unit testing."
    tools: read, bash
    ---

    You are a test specialist.
  MD

  def write_agent(content)
    file = Tempfile.new(["agent_test", ".md"])
    file.write(content)
    file.flush
    file
  end

  def setup
    Agents::Definition  # ensure file is autoloaded
  end

  # ─── from_file ────────────────────────────────────────────────────────────

  test "from_file parses name, description, and prompt" do
    file = write_agent(VALID_AGENT)
    definition = Agents::Definition.from_file(file.path)

    assert_equal "test-agent", definition.name
    assert_equal "A test agent for unit testing.", definition.description
    assert_includes definition.prompt, "test specialist"
  ensure
    file.close; file.unlink
  end

  test "from_file parses tools as array of downcased names" do
    file = write_agent(VALID_AGENT)
    definition = Agents::Definition.from_file(file.path)

    assert_equal %w[read bash], definition.tools
  ensure
    file.close; file.unlink
  end

  test "from_file stores source_path" do
    file = write_agent(VALID_AGENT)
    definition = Agents::Definition.from_file(file.path)

    assert_equal file.path, definition.source_path
  ensure
    file.close; file.unlink
  end

  test "from_file accepts tools as YAML array" do
    agent = <<~MD
      ---
      name: multi-tool
      description: "Has many tools."
      tools:
        - read
        - write
        - think
      ---
      Prompt here.
    MD
    file = write_agent(agent)
    definition = Agents::Definition.from_file(file.path)

    assert_equal %w[read write think], definition.tools
  ensure
    file.close; file.unlink
  end

  test "from_file raises InvalidDefinitionError when frontmatter missing" do
    file = write_agent("No frontmatter here.")
    assert_raises(Agents::InvalidDefinitionError) do
      Agents::Definition.from_file(file.path)
    end
  ensure
    file.close; file.unlink
  end

  test "from_file raises InvalidDefinitionError when name missing" do
    agent = <<~MD
      ---
      description: "Missing name."
      ---
      Prompt.
    MD
    file = write_agent(agent)
    assert_raises(Agents::InvalidDefinitionError) do
      Agents::Definition.from_file(file.path)
    end
  ensure
    file.close; file.unlink
  end

  test "from_file raises InvalidDefinitionError when description missing" do
    agent = <<~MD
      ---
      name: no-desc
      ---
      Prompt.
    MD
    file = write_agent(agent)
    assert_raises(Agents::InvalidDefinitionError) do
      Agents::Definition.from_file(file.path)
    end
  ensure
    file.close; file.unlink
  end

  test "from_file accepts agent with no tools field" do
    agent = <<~MD
      ---
      name: no-tools
      description: "Minimal agent."
      ---
      Prompt.
    MD
    file = write_agent(agent)
    definition = Agents::Definition.from_file(file.path)

    assert_equal [], definition.tools
  ensure
    file.close; file.unlink
  end

  test "from_file parses optional model field" do
    agent = <<~MD
      ---
      name: specific-model
      description: "Uses a specific model."
      model: claude-opus-4-6
      ---
      Prompt.
    MD
    file = write_agent(agent)
    definition = Agents::Definition.from_file(file.path)

    assert_equal "claude-opus-4-6", definition.model
  ensure
    file.close; file.unlink
  end
end
