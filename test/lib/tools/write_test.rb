# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class Tools::WriteTest < ActiveSupport::TestCase
  def setup
    @tool = Tools::Write.new
    @tmpdir = Dir.mktmpdir("anima_write_test")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  test "tool_name is write" do
    assert_equal "write", Tools::Write.tool_name
  end

  test "call creates a new file with given content" do
    path = File.join(@tmpdir, "hello.txt")
    @tool.call("path" => path, "content" => "hello world\n")

    assert File.exist?(path)
    assert_equal "hello world\n", File.read(path)
  end

  test "call returns confirmation with byte count and path" do
    path = File.join(@tmpdir, "hello.txt")
    result = @tool.call("path" => path, "content" => "hello")

    assert_match(/\d+ bytes/, result)
    assert_includes result, path
  end

  test "call overwrites existing file" do
    path = File.join(@tmpdir, "existing.txt")
    File.write(path, "old content")

    @tool.call("path" => path, "content" => "new content")

    assert_equal "new content", File.read(path)
  end

  test "call creates intermediate directories automatically" do
    path = File.join(@tmpdir, "deep/nested/dir/file.txt")
    @tool.call("path" => path, "content" => "nested")

    assert File.exist?(path)
  end

  test "call returns error for blank path" do
    result = @tool.call("path" => "", "content" => "content")
    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "call returns error when path is a directory" do
    result = @tool.call("path" => @tmpdir, "content" => "content")
    assert_kind_of Hash, result
    assert_match(/directory/i, result[:error])
  end

  test "call returns permission denied when parent directory is not writable" do
    subdir = File.join(@tmpdir, "readonly_dir")
    FileUtils.mkdir_p(subdir)
    File.chmod(0555, subdir)
    path = File.join(subdir, "newfile.txt")

    result = @tool.call("path" => path, "content" => "content")

    assert_kind_of Hash, result
    assert_match(/permission denied/i, result[:error])
  ensure
    File.chmod(0755, subdir) rescue nil
  end

  test "call writes empty content" do
    path = File.join(@tmpdir, "empty.txt")
    @tool.call("path" => path, "content" => "")

    assert File.exist?(path)
    assert_equal "", File.read(path)
  end

  test "call preserves exact content without normalization" do
    path = File.join(@tmpdir, "exact.txt")
    content = "line1\r\nline2\r\n"
    @tool.call("path" => path, "content" => content)

    assert_equal content, File.read(path)
  end

  test "params_schema returns an object schema with path and content properties" do
    schema = Tools::Write.new.params_schema
    assert_equal "object", schema["type"]
    assert schema["properties"].key?("path")
    assert schema["properties"].key?("content")
  end

  test "call resolves relative path against working directory when shell_session provided" do
    dir = @tmpdir
    shell = Object.new
    shell.define_singleton_method(:pwd) { dir }
    tool = Tools::Write.new(shell_session: shell)

    tool.call("path" => "relative.txt", "content" => "relative write")

    expected_path = File.join(dir, "relative.txt")
    assert File.exist?(expected_path)
    assert_equal "relative write", File.read(expected_path)
  end
end
