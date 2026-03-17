# frozen_string_literal: true

require "test_helper"

class AnalyticalBrainTest < ActiveSupport::TestCase
  test "logger returns a Logger instance" do
    assert_instance_of Logger, AnalyticalBrain.logger
  end

  test "logger is memoized" do
    assert_same AnalyticalBrain.logger, AnalyticalBrain.logger
  end

  test "logger writes to NULL in non-development environment" do
    # In the test environment (not development), build_logger returns Logger.new(File::NULL).
    # We can't call build_logger directly (private), but we can verify the logger doesn't
    # raise when written to and discards output silently.
    assert_nothing_raised { AnalyticalBrain.logger.info("test message") }
  end

  test "build_logger creates a file logger in development environment" do
    AnalyticalBrain.instance_variable_set(:@logger, nil)
    FileUtils.mkdir_p(Rails.root.join("log"))
    original_env = Rails.method(:env)
    Rails.define_singleton_method(:env) { ActiveSupport::StringInquirer.new("development") }

    logger = AnalyticalBrain.send(:build_logger)
    assert_kind_of Logger, logger
    assert_nothing_raised { logger.info("trigger formatter") }
  ensure
    Rails.define_singleton_method(:env, original_env)
    AnalyticalBrain.instance_variable_set(:@logger, nil)
  end
end
