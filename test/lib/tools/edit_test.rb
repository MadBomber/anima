# frozen_string_literal: true

require "test_helper"
require "tempfile"

class Tools::EditTest < ActiveSupport::TestCase
  def setup
    @tool = Tools::Edit.new
    @tmpdir = Dir.mktmpdir("anima_edit_test")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def write_file(name, content)
    path = File.join(@tmpdir, name)
    File.write(path, content)
    path
  end

  # ─── Basic replacement ───────────────────────────────────────────────────

  test "tool_name is edit" do
    assert_equal "edit", Tools::Edit.tool_name
  end

  test "execute replaces exact text and returns a diff" do
    path = write_file("a.rb", "def hello\n  puts 'hi'\nend\n")
    result = @tool.execute("path" => path, "old_text" => "  puts 'hi'", "new_text" => "  puts 'hello'")

    assert_kind_of String, result
    assert_includes result, "-  puts 'hi'"
    assert_includes result, "+  puts 'hello'"
    assert_equal "def hello\n  puts 'hello'\nend\n", File.read(path)
  end

  test "execute deletes text when new_text is empty" do
    path = write_file("b.rb", "line1\nremove_me\nline3\n")
    @tool.execute("path" => path, "old_text" => "remove_me\n", "new_text" => "")

    assert_equal "line1\nline3\n", File.read(path)
  end

  test "execute returns diff header with file path" do
    path = write_file("c.rb", "foo\nbar\n")
    result = @tool.execute("path" => path, "old_text" => "foo", "new_text" => "baz")

    assert_includes result, "--- #{path}"
    assert_includes result, "+++ #{path}"
  end

  # ─── Fuzzy (whitespace-normalized) match ─────────────────────────────────

  test "execute falls back to fuzzy match when indentation differs" do
    # File uses 4-space indent; old_text uses 2-space — multiline prevents substring match,
    # but fuzzy (whitespace-normalized line) matching succeeds.
    path = write_file("d.rb", "def greet\n    puts 'hi'\nend\n")
    result = @tool.execute(
      "path" => path,
      "old_text" => "def greet\n  puts 'hi'\nend",
      "new_text" => "def greet\n    puts 'hello'\nend"
    )

    assert_kind_of String, result
    assert_includes result, "fuzzy match"
    assert_equal "def greet\n    puts 'hello'\nend\n", File.read(path)
  end

  # ─── Error paths ─────────────────────────────────────────────────────────

  test "execute returns error for blank path" do
    result = @tool.execute("path" => "", "old_text" => "x", "new_text" => "y")

    assert_kind_of Hash, result
    assert_match(/blank/i, result[:error])
  end

  test "execute returns error for blank old_text" do
    path = write_file("e.rb", "content\n")
    result = @tool.execute("path" => path, "old_text" => "", "new_text" => "y")

    assert_kind_of Hash, result
    assert_match(/blank/i, result[:error])
  end

  test "execute returns error when file not found" do
    result = @tool.execute("path" => "/nonexistent/file.rb", "old_text" => "x", "new_text" => "y")

    assert_kind_of Hash, result
    assert_match(/not found/i, result[:error])
  end

  test "execute returns error when path is a directory" do
    result = @tool.execute("path" => @tmpdir, "old_text" => "x", "new_text" => "y")

    assert_kind_of Hash, result
    assert_match(/directory/i, result[:error])
  end

  test "execute returns error when old_text not found in file" do
    path = write_file("f.rb", "hello world\n")
    result = @tool.execute("path" => path, "old_text" => "nonexistent text", "new_text" => "y")

    assert_kind_of Hash, result
    assert_match(/could not find/i, result[:error])
  end

  test "execute returns error when old_text matches multiple locations" do
    path = write_file("g.rb", "foo\nfoo\n")
    result = @tool.execute("path" => path, "old_text" => "foo", "new_text" => "bar")

    assert_kind_of Hash, result
    assert_match(/2 matches/i, result[:error])
  end

  test "execute returns error when old_text and new_text are identical" do
    path = write_file("h.rb", "same content\n")
    result = @tool.execute("path" => path, "old_text" => "same content", "new_text" => "same content")

    assert_kind_of Hash, result
    assert_match(/identical/i, result[:error])
  end

  # ─── input_schema ────────────────────────────────────────────────────────

  test "input_schema returns an object schema with path, old_text, and new_text properties" do
    schema = Tools::Edit.input_schema
    assert_equal "object", schema[:type]
    assert schema[:properties].key?(:path)
    assert schema[:properties].key?(:old_text)
    assert schema[:properties].key?(:new_text)
  end

  # ─── File size limit ─────────────────────────────────────────────────────

  test "execute returns error when file exceeds max_file_size" do
    original = Anima::Settings.config_path
    overridden = Tempfile.new(["edit_size_test", ".toml"])
    begin
      overridden.write(File.read(original).sub(/max_file_size = \d+/, "max_file_size = 5"))
      overridden.flush
      Anima::Settings.config_path = overridden.path

      path = write_file("big.rb", "x" * 10)
      result = @tool.execute("path" => path, "old_text" => "x", "new_text" => "y")

      assert_kind_of Hash, result
      assert_match(/bytes/i, result[:error])
    ensure
      Anima::Settings.config_path = original
      overridden.close; overridden.unlink
    end
  end

  # ─── Relative path resolution ────────────────────────────────────────────

  test "execute resolves relative path when shell_session provides pwd" do
    dir = @tmpdir
    File.write(File.join(dir, "relative.rb"), "original\n")

    shell = Object.new
    shell.define_singleton_method(:pwd) { dir }
    tool = Tools::Edit.new(shell_session: shell)

    tool.execute("path" => "relative.rb", "old_text" => "original", "new_text" => "replaced")

    assert_equal "replaced\n", File.read(File.join(dir, "relative.rb"))
  end
end
