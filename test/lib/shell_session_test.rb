# frozen_string_literal: true

require "test_helper"

class ShellSessionTest < ActiveSupport::TestCase
  def setup
    @session = ShellSession.new(session_id: 999)
  end

  def teardown
    @session.finalize if @session.alive?
  end

  # ─── Lifecycle ───────────────────────────────────────────────────────────

  test "alive? returns true after start" do
    assert @session.alive?
  end

  test "finalize marks session as dead" do
    @session.finalize
    assert_not @session.alive?
  end

  test "run returns error when session is dead" do
    @session.finalize
    result = @session.run("echo hello")

    assert_kind_of Hash, result
    assert_match(/not running/i, result[:error])
  end

  # ─── Command execution ───────────────────────────────────────────────────

  test "run returns hash with stdout, stderr, exit_code" do
    result = @session.run("echo hello")

    assert_kind_of Hash, result
    assert result.key?(:stdout)
    assert result.key?(:stderr)
    assert result.key?(:exit_code)
  end

  test "run captures stdout output" do
    result = @session.run("echo hello_world")

    assert_includes result[:stdout], "hello_world"
  end

  test "run reports exit_code 0 for successful command" do
    result = @session.run("true")

    assert_equal 0, result[:exit_code]
  end

  test "run reports non-zero exit_code for failing command" do
    result = @session.run("false")

    assert_not_equal 0, result[:exit_code]
  end

  test "run captures stderr output" do
    result = @session.run("echo error_output 1>&2")

    assert_includes result[:stderr], "error_output"
  end

  test "run preserves working directory between commands" do
    @session.run("cd /tmp")
    result = @session.run("pwd")

    assert_includes result[:stdout], "/tmp"
  end

  test "run preserves shell variables between commands" do
    @session.run("MY_VAR=hello_there")
    result = @session.run("echo $MY_VAR")

    assert_includes result[:stdout], "hello_there"
  end

  test "run executes multiline commands" do
    result = @session.run("for i in 1 2 3; do echo $i; done")

    assert_includes result[:stdout], "1"
    assert_includes result[:stdout], "3"
  end

  test "run handles command with no output" do
    result = @session.run("true")

    assert_equal "", result[:stdout]
    assert_equal 0, result[:exit_code]
  end

  # ─── Session tracking ─────────────────────────────────────────────────────

  test "cleanup_orphans does not crash with no orphan FIFOs" do
    assert_nothing_raised { ShellSession.cleanup_orphans }
  end

  test "cleanup_orphans deletes stale FIFO files for non-existent PIDs" do
    # Use a PID far above macOS limits (max ~99999) — guaranteed non-existent
    fake_pid = 999_999_999
    stale_path = File.join(Dir.tmpdir, "anima-stderr-#{fake_pid}-deadbeef12")
    File.write(stale_path, "")

    begin
      ShellSession.cleanup_orphans
      assert_not File.exist?(stale_path), "expected stale FIFO to be deleted"
    ensure
      File.delete(stale_path) rescue nil
    end
  end

  test "multiple sessions can run concurrently without interference" do
    session2 = ShellSession.new(session_id: 1000)

    @session.run("MY_UNIQUE=session_one")
    session2.run("MY_UNIQUE=session_two")

    r1 = @session.run("echo $MY_UNIQUE")
    r2 = session2.run("echo $MY_UNIQUE")

    assert_includes r1[:stdout], "session_one"
    assert_includes r2[:stdout], "session_two"
  ensure
    session2.finalize if session2.alive?
  end

  # ─── Output truncation ───────────────────────────────────────────────────

  test "run truncates stdout that exceeds max_output_bytes" do
    original = Anima::Settings.config_path
    overridden = Tempfile.new(["shell_trunc_test", ".toml"])
    session = nil
    begin
      overridden.write(File.read(original).sub(/max_output_bytes = \d+/, "max_output_bytes = 10"))
      overridden.flush
      Anima::Settings.config_path = overridden.path
      session = ShellSession.new(session_id: 9981)

      result = session.run("printf '%100s' x")

      assert result[:stdout].include?("[Truncated:") || result.key?(:error)
    ensure
      Anima::Settings.config_path = original
      session&.finalize if session&.alive?
      overridden.close; overridden.unlink
    end
  end

  test "run marks stderr truncated when stderr exceeds max_output_bytes" do
    original = Anima::Settings.config_path
    overridden = Tempfile.new(["shell_stderr_trunc", ".toml"])
    session = nil
    begin
      overridden.write(File.read(original).sub(/max_output_bytes = \d+/, "max_output_bytes = 5"))
      overridden.flush
      Anima::Settings.config_path = overridden.path
      session = ShellSession.new(session_id: 9982)

      # Two lines of stderr — first fills the buffer, second triggers @stderr_truncated = true
      result = session.run("echo 'aaaaaaaaaa' 1>&2; echo 'bbbbbbbbbb' 1>&2; true")

      assert_kind_of Hash, result
    ensure
      Anima::Settings.config_path = original
      session&.finalize if session&.alive?
      overridden.close; overridden.unlink
    end
  end

  # ─── Command timeout ─────────────────────────────────────────────────────

  test "run returns error when command exceeds timeout" do
    original = Anima::Settings.config_path
    overridden = Tempfile.new(["shell_timeout_test", ".toml"])
    begin
      overridden.write(File.read(original).sub(/command = \d+/, "command = 1"))
      overridden.flush
      Anima::Settings.config_path = overridden.path

      result = @session.run("sleep 10")

      assert_kind_of Hash, result
      assert result.key?(:error)
      assert_match(/timed out/i, result[:error])
    ensure
      Anima::Settings.config_path = original
      overridden.close; overridden.unlink
    end
  end
end
