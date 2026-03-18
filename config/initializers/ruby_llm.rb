# frozen_string_literal: true

# Configure ruby_llm with Anthropic credentials.
#
# Credential resolution order:
#   1. ANTHROPIC_OAUTH_TOKEN env var (OAuth bearer token, sk-ant-oat01-...)
#   2. ANTHROPIC_API_KEY env var (standard API key)
#   3. Rails encrypted credentials: anthropic.subscription_token (OAuth)
#   4. Rails encrypted credentials: anthropic.api_key (standard key)
#
# When an OAuth token is present, LLM::Client adds Authorization: Bearer and
# anthropic-beta: oauth-2025-04-20 per-request via with_headers. Anthropic
# accepts both x-api-key and Authorization: Bearer simultaneously, so no
# provider patching is required.
require "ruby_llm"

anthropic_key = ENV["ANTHROPIC_OAUTH_TOKEN"].presence ||
                ENV["ANTHROPIC_API_KEY"].presence ||
                begin
                  Rails.application.credentials.dig(:anthropic, :subscription_token) ||
                    Rails.application.credentials.dig(:anthropic, :api_key)
                rescue
                  nil
                end

unless anthropic_key
  Rails.logger.warn "[ruby_llm] No Anthropic credentials found — LLM calls will fail. " \
                    "Set ANTHROPIC_OAUTH_TOKEN or ANTHROPIC_API_KEY."
end

RubyLLM.configure do |config|
  config.anthropic_api_key = anthropic_key
  config.request_timeout   = Anima::Settings.api_timeout
  config.ollama_api_base   = ENV.fetch("OLLAMA_API_BASE", "http://localhost:11434/v1")
end
