# frozen_string_literal: true

require "test_helper"

class StaleSessionLockJobTest < ActiveSupport::TestCase
  THRESHOLD = StaleSessionLockJob::STALE_THRESHOLD

  def setup
    @job = StaleSessionLockJob.new
  end

  test "does nothing when no sessions are locked" do
    assert_no_changes -> { Session.where(processing: true).count } do
      @job.perform
    end
  end

  test "clears processing lock when locked_at is older than the threshold" do
    session = Session.create!(processing: true, locked_at: (THRESHOLD + 1.minute).ago)

    @job.perform

    session.reload
    assert_equal false, session.processing
    assert_nil session.locked_at
  end

  test "does not clear locks held for less than the threshold" do
    session = Session.create!(processing: true, locked_at: (THRESHOLD - 1.minute).ago)

    @job.perform

    session.reload
    assert_equal true, session.processing
    assert_not_nil session.locked_at
  end

  test "does not touch sessions that are not processing" do
    session = Session.create!(processing: false, locked_at: (THRESHOLD + 1.hour).ago)

    @job.perform

    session.reload
    assert_equal false, session.processing
  end

  test "clears multiple stale locks in a single pass" do
    stale1 = Session.create!(processing: true, locked_at: (THRESHOLD + 5.minutes).ago)
    stale2 = Session.create!(processing: true, locked_at: (THRESHOLD + 10.minutes).ago)
    fresh  = Session.create!(processing: true, locked_at: 1.minute.ago)

    @job.perform

    assert_equal false, stale1.reload.processing
    assert_equal false, stale2.reload.processing
    assert_equal true,  fresh.reload.processing
  end

  test "logs a warning when stale locks are released" do
    Session.create!(processing: true, locked_at: (THRESHOLD + 1.minute).ago)

    assert_nothing_raised do
      @job.perform
    end
  end
end
