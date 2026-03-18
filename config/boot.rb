# frozen_string_literal: true

gemfile = File.expand_path("../Gemfile", __dir__)

if File.exist?(gemfile)
  ENV["BUNDLE_GEMFILE"] ||= gemfile
  require "bundler/setup"
end

# Start SimpleCov before the application loads so that files required from
# config/application.rb (e.g. lib/anima.rb) are tracked from the beginning.
# The full filter/group configuration is applied in test/test_helper.rb via a
# second SimpleCov.start call, which reconfigures without restarting Coverage.
#
# ARGV still contains "test" at this point when invoked as `rails test`.
# Individual file runs (`ruby test/foo.rb`) don't hit this path, but for those
# the environment is loaded after SimpleCov.start in test_helper.rb anyway.
if ARGV.any? { |a| a == "test" || a.start_with?("test/") }
  begin
    require "simplecov"
    SimpleCov.start
  rescue LoadError
    # simplecov is only present in the test bundle; silently skip otherwise.
  end
end
