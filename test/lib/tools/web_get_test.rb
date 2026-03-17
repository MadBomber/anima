# frozen_string_literal: true

require "test_helper"

class Tools::WebGetTest < ActiveSupport::TestCase
  def setup
    @tool = Tools::WebGet.new
  end

  test "tool_name is web_get" do
    assert_equal "web_get", Tools::WebGet.tool_name
  end

  test "execute returns error for blank url" do
    result = @tool.execute("url" => "")

    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "execute returns error for non-http scheme (ftp)" do
    result = @tool.execute("url" => "ftp://example.com/file.txt")

    assert_kind_of Hash, result
    assert_match(/ftp/i, result[:error])
  end

  test "execute returns error for non-http scheme (file)" do
    result = @tool.execute("url" => "file:///etc/passwd")

    assert_kind_of Hash, result
    assert_match(/file/i, result[:error])
  end

  test "execute returns error for invalid URI" do
    result = @tool.execute("url" => "not a url !! ##")

    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "execute returns error when nil scheme (bare string)" do
    result = @tool.execute("url" => "justplaintext")

    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "execute returns error when connection is refused" do
    # Port 1 is reserved and will be refused on all platforms
    result = @tool.execute("url" => "http://127.0.0.1:1/")

    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "input_schema returns an object schema with url property" do
    schema = Tools::WebGet.input_schema
    assert_equal "object", schema[:type]
    assert schema[:properties].key?(:url)
  end

  test "execute returns error for unresolvable hostname" do
    # .invalid TLD is guaranteed non-resolving per RFC 2606
    result = @tool.execute("url" => "http://no-such-host.invalid/")

    assert_kind_of Hash, result
    assert result.key?(:error)
  end

  test "execute returns error when request times out" do
    require "socket"

    original = Anima::Settings.config_path
    overridden = Tempfile.new(["web_timeout_test", ".toml"])
    begin
      overridden.write(File.read(original).sub(/web_request = \d+/, "web_request = 1"))
      overridden.flush
      Anima::Settings.config_path = overridden.path

      port = rand(20000..40000)
      server = TCPServer.new("127.0.0.1", port)
      thread = Thread.new do
        client = server.accept
        sleep 5
        client.close rescue nil
      end

      begin
        result = @tool.execute("url" => "http://127.0.0.1:#{port}/")
        assert_kind_of Hash, result
        assert result.key?(:error)
        assert_match(/timed out/i, result[:error])
      ensure
        server.close rescue nil
        thread.kill
        thread.join(0.1) rescue nil
      end
    ensure
      Anima::Settings.config_path = original
      overridden.close; overridden.unlink
    end
  end

  test "execute truncates response body that exceeds max_web_response_bytes" do
    require "webrick"

    port = rand(10000..30000)
    server = WEBrick::HTTPServer.new(
      Port: port,
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )
    big_body = "x" * (Anima::Settings.max_web_response_bytes + 100)
    server.mount_proc("/big") { |_req, res| res.body = big_body }

    thread = Thread.new { server.start }
    sleep 0.05

    begin
      result = @tool.execute("url" => "http://127.0.0.1:#{port}/big")

      assert_kind_of String, result
      assert_includes result, "[Truncated:"
    ensure
      server.shutdown
      thread.join(2)
    end
  end
end
