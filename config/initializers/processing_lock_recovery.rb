# frozen_string_literal: true

# Clears stale processing locks left by a previous process that crashed before
# releasing them. Any session marked processing=true with locked_at older than
# 10 minutes is assumed orphaned and reset so new jobs can run.
#
# Runs after_initialize (after DB is ready). Safe to call on every boot:
# clears only locks that are clearly stale — not ones held by concurrent
# processes that started recently.
Rails.application.config.after_initialize do
  next unless ActiveRecord::Base.connection.table_exists?(:sessions)

  stale_cutoff = 10.minutes.ago
  stale_count  = Session.where(processing: true)
    .where(locked_at: ...stale_cutoff)
    .update_all(processing: false, locked_at: nil)

  if stale_count > 0
    Rails.logger.warn "[ProcessingLockRecovery] Cleared #{stale_count} stale processing lock(s) (locked_at < #{stale_cutoff})"
  end
end
