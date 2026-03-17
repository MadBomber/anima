# frozen_string_literal: true

require "test_helper"
require "tempfile"

class Tools::ReadTest < ActiveSupport::TestCase
  def setup
    @tool = Tools::Read.new
    @tmpfile = Tempfile.new(["anima_read_test", ".txt"])
  end

  def teardown
    @tmpfile.close
    @tmpfile.unlink
  end

  test "tool_name is read" do
    assert_equal "read", Tools::Read.tool_name
  end

  test "execute reads file contents" do
    @tmpfile.write("hello\nworld\n")
    @tmpfile.flush

    result = @tool.execute({"path" => @tmpfile.path})

    assert_includes result, "hello"
    assert_includes result, "world"
  end

  test "execute returns error for blank path" do
    result = @tool.execute({"path" => ""})
    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "execute returns error for non-existent file" do
    result = @tool.execute({"path" => "/nonexistent/path/file.txt"})
    assert_kind_of Hash, result
    assert_match(/not found/i, result[:error])
  end

  test "execute returns error for directory path" do
    result = @tool.execute({"path" => Dir.tmpdir})
    assert_kind_of Hash, result
    assert_match(/directory/i, result[:error])
  end

  test "execute respects offset parameter" do
    @tmpfile.write("line1\nline2\nline3\nline4\nline5\n")
    @tmpfile.flush

    result = @tool.execute({"path" => @tmpfile.path, "offset" => 3})

    assert_includes result, "line3"
    assert_not_includes result, "line1"
  end

  test "execute respects limit parameter" do
    @tmpfile.write((1..20).map { |i| "line#{i}" }.join("\n") + "\n")
    @tmpfile.flush

    result = @tool.execute({"path" => @tmpfile.path, "limit" => 3})

    assert_includes result, "line1"
    assert_includes result, "line3"
    assert_not_includes result, "line4"
  end

  test "execute returns truncation hint when file has more lines" do
    @tmpfile.write((1..100).map { |i| "line#{i}" }.join("\n") + "\n")
    @tmpfile.flush

    result = @tool.execute({"path" => @tmpfile.path, "limit" => 5})

    assert_match(/offset=\d+/, result)
  end

  test "execute returns empty string for empty file" do
    # file is empty — nothing written

    result = @tool.execute({"path" => @tmpfile.path})
    assert_equal "", result
  end

  test "execute returns error when offset is beyond end of file" do
    @tmpfile.write("one line\n")
    @tmpfile.flush

    result = @tool.execute({"path" => @tmpfile.path, "offset" => 999})

    assert_kind_of String, result
    assert_match(/beyond end of file/i, result)
  end

  test "input_schema returns an object schema with path property" do
    schema = Tools::Read.input_schema
    assert_equal "object", schema[:type]
    assert schema[:properties].key?(:path)
  end

  test "execute returns error for file exceeding max_file_size" do
    require "tmpdir"
    # Set max_file_size to 5 bytes via config
    original = Anima::Settings.config_path
    overridden = Tempfile.new(["read_size_test", ".toml"])
    begin
      content = File.read(original)
      # Override max_file_size to be tiny
      overridden.write(content.sub(/max_file_size = \d+/, "max_file_size = 5"))
      overridden.flush
      Anima::Settings.config_path = overridden.path

      big_file = Tempfile.new(["big_file", ".txt"])
      big_file.write("x" * 10)
      big_file.flush

      result = @tool.execute({"path" => big_file.path})

      assert_kind_of Hash, result
      assert_match(/bytes/i, result[:error])
    ensure
      Anima::Settings.config_path = original
      overridden.close; overridden.unlink
      big_file&.close; big_file&.unlink
    end
  end

  test "execute returns error for line exceeding max_read_bytes" do
    require "tmpdir"
    original = Anima::Settings.config_path
    overridden = Tempfile.new(["read_bytes_test", ".toml"])
    begin
      content = File.read(original)
      overridden.write(content.sub(/max_read_bytes = \d+/, "max_read_bytes = 5"))
      overridden.flush
      Anima::Settings.config_path = overridden.path

      @tmpfile.write("x" * 100 + "\n")
      @tmpfile.flush

      result = @tool.execute({"path" => @tmpfile.path})

      assert_kind_of Hash, result
      assert_match(/exceeds/i, result[:error])
    ensure
      Anima::Settings.config_path = original
      overridden.close; overridden.unlink
    end
  end

  test "execute resolves relative path against working directory when shell_session provided" do
    dir = File.dirname(@tmpfile.path)
    filename = File.basename(@tmpfile.path)
    @tmpfile.write("relative content\n")
    @tmpfile.flush

    shell = Object.new
    shell.define_singleton_method(:pwd) { dir }
    tool = Tools::Read.new(shell_session: shell)

    result = tool.execute({"path" => filename})
    assert_includes result, "relative content"
  end
end
