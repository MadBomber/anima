# frozen_string_literal: true

# Broadcasts Session state changes to connected WebSocket clients via ActionCable.
# Mirrors the Event::Broadcasting pattern: after_update_commit callbacks emit
# targeted payloads so the TUI info panel updates in real time when the
# analytical brain changes the session name, activates skills, or switches workflows.
module Session::Broadcasts
  extend ActiveSupport::Concern

  included do
    after_update_commit :broadcast_name_update,            if: :saved_change_to_name?
    after_update_commit :broadcast_active_skills_update,   if: :saved_change_to_active_skills?
    after_update_commit :broadcast_active_workflow_update, if: :saved_change_to_active_workflow?
  end

  private

  # @return [void]
  def broadcast_name_update
    ActionCable.server.broadcast("session_#{id}", {
      "action"     => "session_name_updated",
      "session_id" => id,
      "name"       => name
    })
  end

  # @return [void]
  def broadcast_active_skills_update
    ActionCable.server.broadcast("session_#{id}", {
      "action"        => "active_skills_updated",
      "session_id"    => id,
      "active_skills" => active_skills
    })
  end

  # @return [void]
  def broadcast_active_workflow_update
    ActionCable.server.broadcast("session_#{id}", {
      "action"          => "active_workflow_updated",
      "session_id"      => id,
      "active_workflow" => active_workflow
    })
  end
end
