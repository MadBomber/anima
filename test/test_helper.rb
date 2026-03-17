# frozen_string_literal: true

require "simplecov"
SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/spec/"

  # ── Excluded: require live external services or terminal I/O ──────────
  # TUI — terminal rendering, not unit-testable
  add_filter "lib/tui/"
  # LLM / Provider — real Anthropic API calls
  add_filter "lib/llm/client.rb"
  add_filter "lib/providers/anthropic.rb"
  # MCP — requires real server connections or spawned processes
  add_filter "lib/mcp/stdio_transport.rb"
  add_filter "lib/mcp/health_check.rb"
  add_filter "lib/mcp/client_manager.rb"
  # Tools that spawn sub-agents (need running LLM loop)
  add_filter "lib/tools/spawn_subagent.rb"
  add_filter "lib/tools/spawn_specialist.rb"
  add_filter "lib/tools/request_feature.rb"
  add_filter "lib/tools/mcp_tool.rb"
  # Analytical brain runner — drives full LLM loop
  add_filter "lib/analytical_brain/runner.rb"
  # Agent loop — orchestrates full LLM session
  add_filter "lib/agent_loop.rb"
  # Jobs that run the full agent/brain loop
  add_filter "app/jobs/agent_request_job.rb"
  add_filter "app/jobs/analytical_brain_job.rb"
  # CLI — Thor-based commands, integration-level
  add_filter "lib/anima/cli.rb"
  add_filter "lib/anima/cli/"
  # Installer / migrator — writes to ~/.anima, system-level
  add_filter "lib/anima/installer.rb"
  add_filter "lib/anima/config_migrator.rb"
  # ActionCable channels — WebSocket, needs live cable server
  add_filter "app/channels/"
  # Credential store — writes to Rails encrypted credentials on disk
  add_filter "lib/credential_store.rb"
  add_filter "lib/mcp/secrets.rb"
  # Controllers (no controller tests in this app)
  add_filter "app/controllers/"
  # Loaded by gemspec before SimpleCov starts — can't be tracked
  add_filter "lib/anima/version.rb"

  add_group "Models",           "app/models"
  add_group "Jobs",             "app/jobs"
  add_group "Decorators",       "app/decorators"
  add_group "Tools",            "lib/tools"
  add_group "Events",           "lib/events"
  add_group "Analytical Brain", "lib/analytical_brain"
  add_group "MCP",              "lib/mcp"
  add_group "Agents",           "lib/agents"
  add_group "Workflows",        "lib/workflows"
  add_group "Skills",           "lib/skills"
  add_group "Anima",            "lib/anima"
end

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

# Ensure the test database schema is current.
ActiveRecord::Tasks::DatabaseTasks.prepare_all

# Generate a test config so tests never touch ~/.anima/config.toml.
# Written to tmp/ (already gitignored by Rails).
soul_path = Rails.root.join("test/fixtures/soul.md").to_s
test_config_path = Rails.root.join("tmp/test_config.toml").to_s

FileUtils.mkdir_p(Rails.root.join("tmp"))
File.write(test_config_path, <<~TOML)
  [llm]
  model = "claude-sonnet-4-6"
  fast_model = "claude-haiku-4-5"
  max_tokens = 8192
  max_tool_rounds = 500
  token_budget = 190000

  [timeouts]
  api = 300
  command = 30
  mcp_response = 60
  web_request = 10

  [shell]
  max_output_bytes = 100000

  [tools]
  max_file_size = 10485760
  max_read_lines = 2000
  max_read_bytes = 50000
  max_web_response_bytes = 100000

  [environment]
  project_files = ["CLAUDE.md", "AGENTS.md", "README.md", "CONTRIBUTING.md"]
  project_files_max_depth = 3

  [github]
  repo = "test/anima"
  label = "anima-wants"

  [paths]
  soul = "#{soul_path}"

  [session]
  name_generation_interval = 30

  [analytical_brain]
  max_tokens = 4096
  blocking_on_user_message = true
  blocking_on_agent_message = false
  event_window = 20
TOML

Anima::Settings.config_path = test_config_path

class ActiveSupport::TestCase
  include ActiveJob::TestHelper

  self.use_transactional_tests = true
end
