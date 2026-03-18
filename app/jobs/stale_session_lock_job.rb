# frozen_string_literal: true

# Periodically clears processing locks that have been held too long.
#
# Complements {ProcessingLockRecovery} (which only runs at boot) by
# recovering from crashed processes without requiring a restart.
# A lock held longer than STALE_THRESHOLD is assumed orphaned — the
# job that claimed it either crashed hard or is running unreasonably long.
#
# Scheduled via config/recurring.yml (every 10 minutes). Safe to call
# concurrently: update_all is atomic and only touches provably stale rows.
class StaleSessionLockJob < ApplicationJob
  queue_as :default

  # Locks older than this are released. Chosen to exceed the longest
  # realistic agent run (api_timeout × max_tool_rounds) with margin.
  STALE_THRESHOLD = 30.minutes

  def perform
    stale_cutoff = STALE_THRESHOLD.ago
    stale_count = Session.where(processing: true)
      .where(locked_at: ...stale_cutoff)
      .update_all(processing: false, locked_at: nil)

    if stale_count > 0
      Rails.logger.warn(
        "[StaleSessionLockJob] Released #{stale_count} stale lock(s) " \
        "(locked_at < #{stale_cutoff})"
      )
    end
  end
end
