# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class EnvironmentProbeTest < ActiveSupport::TestCase
  def setup
    @tmpdir = Dir.mktmpdir("anima_env_probe_test")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  # ─── to_prompt ────────────────────────────────────────────────────────

  test "to_prompt returns nil when pwd is nil" do
    assert_nil EnvironmentProbe.to_prompt(nil)
  end

  test "to_prompt returns a markdown string starting with ## Environment" do
    result = EnvironmentProbe.to_prompt(@tmpdir)

    assert_kind_of String, result
    assert result.start_with?("## Environment")
  end

  test "to_prompt includes CWD line with the given directory" do
    result = EnvironmentProbe.to_prompt(@tmpdir)

    assert_includes result, "CWD: #{@tmpdir}"
  end

  test "to_prompt includes OS section" do
    result = EnvironmentProbe.to_prompt(@tmpdir)

    assert_match(/OS:/, result)
  end

  # ─── project_files_section ───────────────────────────────────────────

  test "to_prompt lists a README.md when present in the directory" do
    File.write(File.join(@tmpdir, "README.md"), "# Project")
    result = EnvironmentProbe.to_prompt(@tmpdir)

    assert_includes result, "README.md"
  end

  test "to_prompt does not include project files section when directory is empty" do
    result = EnvironmentProbe.to_prompt(@tmpdir)

    refute_includes result, "Project files"
  end

  test "to_prompt includes multiple whitelisted files" do
    File.write(File.join(@tmpdir, "CLAUDE.md"), "# instructions")
    File.write(File.join(@tmpdir, "README.md"), "# readme")
    result = EnvironmentProbe.to_prompt(@tmpdir)

    assert_includes result, "CLAUDE.md"
    assert_includes result, "README.md"
  end

  # ─── OS detection ─────────────────────────────────────────────────────

  test "EnvironmentProbe instance returns non-nil prompt for valid directory" do
    probe = EnvironmentProbe.new(@tmpdir)
    assert_not_nil probe.to_prompt
  end

  test "EnvironmentProbe instance returns nil when pwd is nil" do
    probe = EnvironmentProbe.new(nil)
    assert_nil probe.to_prompt
  end

  # ─── format_os branches ──────────────────────────────────────────────────

  test "format_os returns Linux distro string when sysname is Linux" do
    probe = EnvironmentProbe.new(@tmpdir)
    result = probe.send(:format_os, "Linux")

    assert_kind_of String, result
    assert_not_empty result
  end

  test "format_os returns sysname string for unknown OS" do
    probe = EnvironmentProbe.new(@tmpdir)
    result = probe.send(:format_os, "FreeBSD")

    assert_equal "FreeBSD", result
  end

  # ─── detect_package_manager ──────────────────────────────────────────────

  test "detect_package_manager returns a string or nil" do
    probe = EnvironmentProbe.new(@tmpdir)
    result = probe.send(:detect_package_manager)

    assert result.nil? || result.is_a?(String)
  end

  # ─── detect_linux_distro ─────────────────────────────────────────────────

  test "detect_linux_distro returns nil or a string" do
    probe = EnvironmentProbe.new(@tmpdir)
    result = probe.send(:detect_linux_distro)

    assert result.nil? || result.is_a?(String)
  end

  # ─── extract_repo_name ───────────────────────────────────────────────────

  test "extract_repo_name handles https remote URL" do
    probe = EnvironmentProbe.new(@tmpdir)
    result = probe.send(:extract_repo_name, "https://github.com/foo/bar.git")

    assert_equal "foo/bar", result
  end

  test "extract_repo_name handles SSH remote URL" do
    probe = EnvironmentProbe.new(@tmpdir)
    result = probe.send(:extract_repo_name, "git@github.com:foo/bar.git")

    assert_equal "foo/bar", result
  end

  test "extract_repo_name returns original URL when URI is invalid" do
    probe = EnvironmentProbe.new(@tmpdir)
    bad_url = "https://host with spaces/repo.git"
    result = probe.send(:extract_repo_name, bad_url)

    assert_equal bad_url, result
  end

  # ─── detect_git in a real git repo ───────────────────────────────────────

  test "to_prompt includes git metadata when run in a git repository" do
    result = EnvironmentProbe.to_prompt(Rails.root.to_s)

    assert_kind_of String, result
    assert_includes result, "Branch:"
  end

  test "detect_git returns nil when git binary is not found" do
    probe = EnvironmentProbe.new(@tmpdir)
    old_path = ENV["PATH"]
    begin
      ENV["PATH"] = "/nonexistent_bin_path"
      result = probe.send(:detect_git)
      assert_nil result
    ensure
      ENV["PATH"] = old_path
    end
  end

  test "detect_pr returns nil when gh binary is not found" do
    probe = EnvironmentProbe.new(Rails.root.to_s)
    old_path = ENV["PATH"]
    begin
      ENV["PATH"] = "/nonexistent_bin_path"
      result = probe.send(:detect_pr, "some-branch")
      assert_nil result
    ensure
      ENV["PATH"] = old_path
    end
  end
end
