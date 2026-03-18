# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class Mcp::ConfigTest < ActiveSupport::TestCase
  def setup
    @tmpdir = Dir.mktmpdir("anima_mcp_config_test")
    @config_path = File.join(@tmpdir, "mcp.toml")
    @config = Mcp::Config.new(path: @config_path)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  # ─── Empty / missing config ──────────────────────────────────────────────

  test "all_servers returns empty array when config file does not exist" do
    assert_equal [], @config.all_servers
  end

  test "http_servers returns empty array when config file does not exist" do
    assert_equal [], @config.http_servers
  end

  test "stdio_servers returns empty array when config file does not exist" do
    assert_equal [], @config.stdio_servers
  end

  # ─── add_server ─────────────────────────────────────────────────────────

  test "add_server creates the config file if it does not exist" do
    @config.add_server("my-server", {"transport" => "http", "url" => "http://localhost:3000/mcp"})

    assert File.exist?(@config_path)
  end

  test "add_server appends a server to the config" do
    @config.add_server("my-server", {"transport" => "http", "url" => "http://localhost:3000/mcp"})

    assert_equal 1, @config.all_servers.size
    assert_equal "my-server", @config.all_servers.first["name"]
  end

  test "add_server raises ArgumentError when server already exists" do
    @config.add_server("dup", {"transport" => "http", "url" => "http://host/mcp"})

    assert_raises(ArgumentError) do
      @config.add_server("dup", {"transport" => "http", "url" => "http://host/mcp"})
    end
  end

  test "add_server raises ArgumentError for invalid name with spaces" do
    assert_raises(ArgumentError) do
      @config.add_server("bad name", {"transport" => "http"})
    end
  end

  test "add_server raises ArgumentError for name with special chars" do
    assert_raises(ArgumentError) do
      @config.add_server("bad@name!", {"transport" => "http"})
    end
  end

  # ─── remove_server ──────────────────────────────────────────────────────

  test "remove_server deletes the named server" do
    @config.add_server("to-remove", {"transport" => "http", "url" => "http://host/mcp"})
    @config.remove_server("to-remove")

    assert_equal [], @config.all_servers
  end

  test "remove_server raises ArgumentError when server not found" do
    assert_raises(ArgumentError) { @config.remove_server("nonexistent") }
  end

  # ─── http_servers ────────────────────────────────────────────────────────

  test "http_servers returns configs with name, url, headers (no credential interpolation)" do
    @config.add_server("plain-http", {
      "transport" => "http",
      "url" => "http://localhost:8080/mcp",
      "headers" => {}
    })

    servers = @config.http_servers
    assert_equal 1, servers.size
    assert_equal "plain-http", servers.first[:name]
    assert_equal "http://localhost:8080/mcp", servers.first[:url]
  end

  test "http_servers skips server with missing url and records a warning" do
    @config.add_server("no-url", {"transport" => "http"})

    servers = @config.http_servers
    assert_equal 0, servers.size
    assert @config.warnings.any? { |w| w.include?("no url") }
  end

  test "http_servers ignores stdio servers" do
    @config.add_server("stdio-srv", {"transport" => "stdio", "command" => "mcp-server"})

    assert_equal [], @config.http_servers
  end

  # ─── stdio_servers ──────────────────────────────────────────────────────

  test "stdio_servers returns configs with name, command, args, env" do
    @config.add_server("fs-server", {
      "transport" => "stdio",
      "command" => "mcp-server-filesystem",
      "args" => ["--root", "/workspace"]
    })

    servers = @config.stdio_servers
    assert_equal 1, servers.size
    assert_equal "fs-server", servers.first[:name]
    assert_equal "mcp-server-filesystem", servers.first[:command]
    assert_equal ["--root", "/workspace"], servers.first[:args]
  end

  test "stdio_servers skips server with missing command and records a warning" do
    @config.add_server("no-cmd", {"transport" => "stdio"})

    servers = @config.stdio_servers
    assert_equal 0, servers.size
    assert @config.warnings.any? { |w| w.include?("no command") }
  end

  test "stdio_servers ignores http servers" do
    @config.add_server("http-srv", {"transport" => "http", "url" => "http://host/mcp"})

    assert_equal [], @config.stdio_servers
  end

  # ─── Multiple servers round-trip ────────────────────────────────────────

  test "all_servers returns all configured servers regardless of transport" do
    @config.add_server("srv1", {"transport" => "http", "url" => "http://a/mcp"})
    @config.add_server("srv2", {"transport" => "stdio", "command" => "cmd"})

    names = @config.all_servers.map { |s| s["name"] }
    assert_includes names, "srv1"
    assert_includes names, "srv2"
  end
end
