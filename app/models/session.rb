# frozen_string_literal: true

# A conversation session — the fundamental unit of agent interaction.
# Owns an ordered stream of {Event} records representing everything that
# happened: user messages, agent responses, tool calls, etc.
#
# Sessions form a hierarchy: a main session can spawn child sessions
# (sub-agents) that inherit the parent's viewport context at fork time.
#
# Behaviour is split across focused concerns:
#   - {Session::Broadcasts}         — ActionCable broadcasting for state changes
#   - {Session::SkillsAndWorkflows} — skill and workflow lifecycle
#   - {Session::ContextWindow}      — LLM context window assembly and message formatting
#   - {Session::SystemPrompt}       — system prompt composition
class Session < ApplicationRecord
  class MissingSoulError < StandardError; end

  VIEW_MODES = %w[basic verbose debug].freeze

  include Session::Broadcasts
  include Session::SkillsAndWorkflows
  include Session::ContextWindow
  include Session::SystemPrompt

  # ── Associations ──────────────────────────────────────────────────────────

  has_many :events, -> { order(:id) }, dependent: :destroy
  has_many :goals, dependent: :destroy

  belongs_to :parent_session, class_name: "Session", optional: true
  has_many :child_sessions, class_name: "Session",
    foreign_key: :parent_session_id, dependent: :destroy

  # ── Validations ───────────────────────────────────────────────────────────

  validates :view_mode, inclusion: {in: VIEW_MODES}
  validates :name, length: {maximum: 255}, allow_nil: true

  # ── Scopes ────────────────────────────────────────────────────────────────

  scope :recent,        ->(limit = 10) { order(updated_at: :desc).limit(limit) }
  scope :root_sessions, -> { where(parent_session_id: nil) }

  # ── Identity ──────────────────────────────────────────────────────────────

  # @return [Boolean] true if this session is a sub-agent (has a parent)
  def sub_agent?
    parent_session_id.present?
  end

  # Cycles to the next view mode: basic → verbose → debug → basic.
  #
  # @return [String] the next view mode
  def next_view_mode
    current_index = VIEW_MODES.index(view_mode) || 0
    VIEW_MODES[(current_index + 1) % VIEW_MODES.size]
  end

  # ── Brain scheduling ──────────────────────────────────────────────────────

  # Enqueues the analytical brain for background session maintenance.
  # Skipped for sub-agents and when a brain job is already queued or running
  # for this session. Uses an atomic check-and-set on brain_scheduled to
  # prevent multiple concurrent enqueues from rapid message bursts.
  #
  # @return [void]
  def schedule_analytical_brain!
    return if sub_agent?

    count = events.llm_messages.count
    return if count < 2
    return if name.present? && (count % Anima::Settings.name_generation_interval != 0)

    # Atomically claim the scheduling slot. If another caller already set the
    # flag, update_all returns 0 rows and we bail — one job is already coming.
    claimed = Session.where(id: id, brain_scheduled: false)
      .update_all(brain_scheduled: true)
    return if claimed == 0

    AnalyticalBrainJob.perform_later(id)
  end

  # ── Display ───────────────────────────────────────────────────────────────

  # Serializes active goals as a lightweight summary for ActionCable
  # broadcasts and TUI display.
  #
  # @return [Array<Hash>] each with :id, :description, :status, and :sub_goals
  def goals_summary
    goals.root.includes(:sub_goals).order(:created_at).map(&:as_summary)
  end
end
