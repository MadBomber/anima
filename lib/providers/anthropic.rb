# frozen_string_literal: true

require "faraday"

module Providers
  # Anthropic-specific utilities that are not covered by the ruby_llm gem:
  # - Token counting (Anthropic-only endpoint)
  # - Credential validation (for the TUI token-setup flow)
  # - Shared error hierarchy (referenced by job retry/discard declarations)
  #
  # Chat requests are handled by {LLM::Client} via the ruby_llm gem.
  class Anthropic
    API_BASE    = "https://api.anthropic.com"
    API_VERSION = "2023-06-01"
    OAUTH_BETA  = "oauth-2025-04-20"

    TOKEN_PREFIX     = "sk-ant-oat01-"
    TOKEN_MIN_LENGTH = 80

    # ── Error hierarchy ──────────────────────────────────────────────────────

    class Error < StandardError; end
    class AuthenticationError < Error; end
    class TokenFormatError < Error; end

    # Transient errors eligible for job-level retries.
    class TransientError < Error; end
    class RateLimitError < TransientError; end
    class ServerError < TransientError; end

    # ── Class-level helpers (used by session_channel token setup) ─────────

    class << self
      # Validates the token string format before making any API call.
      def validate_token_format!(token)
        unless token.start_with?(TOKEN_PREFIX)
          raise TokenFormatError,
            "Token must start with '#{TOKEN_PREFIX}'. Got: '#{token[0..12]}...'"
        end

        unless token.length >= TOKEN_MIN_LENGTH
          raise TokenFormatError,
            "Token must be at least #{TOKEN_MIN_LENGTH} characters (got #{token.length})"
        end

        true
      end

      # Validates the token against the live Anthropic API.
      def validate_token_api!(token)
        new(token).validate_credentials!
      end
    end

    # ── Instance ─────────────────────────────────────────────────────────────

    def initialize(token = nil)
      @token = token || resolve_token
    end

    # Counts tokens in a message payload without creating a message.
    # Uses the Anthropic token counting endpoint (/v1/messages/count_tokens).
    #
    # @param model [String] Anthropic model identifier
    # @param messages [Array<Hash>] conversation messages
    # @param options [Hash] additional parameters (e.g. +system:+, +tools:+)
    # @return [Integer] estimated input token count
    # @raise [Error] on API errors
    def count_tokens(model:, messages:, **options)
      body = {model: model, messages: messages}.merge(options)
      response = connection.post("/v1/messages/count_tokens", body.to_json, request_headers)
      handle_response(response)["input_tokens"]
    rescue Faraday::Error => e
      raise TransientError, "#{e.class}: #{e.message}"
    end

    # Sends a minimal API request to verify the token is accepted.
    #
    # @raise [AuthenticationError] if the token is rejected
    def validate_credentials!
      body = {
        model: Anima::Settings.model,
        messages: [{role: "user", content: "Hi"}],
        max_tokens: 1
      }
      response = connection.post("/v1/messages", body.to_json, request_headers)

      case response.status
      when 200
        true
      when 401
        raise AuthenticationError,
          "Token rejected by Anthropic API (401). Re-run `claude setup-token` and use the TUI token setup (Ctrl+a → a)."
      when 403
        raise AuthenticationError,
          "Token not authorized for API access (403). This credential may be restricted to Claude Code only."
      else
        handle_response(response)
      end
    rescue Faraday::Error => e
      raise TransientError, "#{e.class}: #{e.message}"
    end

    private

    def resolve_token
      ENV["ANTHROPIC_OAUTH_TOKEN"].presence ||
        ENV["ANTHROPIC_API_KEY"].presence ||
        begin
          Rails.application.credentials.dig(:anthropic, :subscription_token)
        rescue
          nil
        end
    end

    def connection
      @connection ||= Faraday.new(API_BASE) do |f|
        f.options.timeout = Anima::Settings.api_timeout
        f.request :json
        f.response :json
      end
    end

    def request_headers
      if @token&.start_with?(TOKEN_PREFIX)
        {
          "Authorization"  => "Bearer #{@token}",
          "anthropic-version" => API_VERSION,
          "anthropic-beta" => OAUTH_BETA,
          "content-type"   => "application/json"
        }
      else
        {
          "x-api-key"         => @token.to_s,
          "anthropic-version" => API_VERSION,
          "content-type"      => "application/json"
        }
      end
    end

    def handle_response(response)
      case response.status
      when 200
        response.body
      when 400
        raise Error, "Bad request: #{error_message(response)}"
      when 401
        raise AuthenticationError, "Authentication failed (401): #{error_message(response)}"
      when 403
        raise AuthenticationError, "Forbidden (403): #{error_message(response)}"
      when 429
        raise RateLimitError, "Rate limit exceeded: #{error_message(response)}"
      when 500..599
        raise ServerError, "Anthropic server error (#{response.status})"
      else
        raise Error, "Unexpected response (#{response.status})"
      end
    end

    def error_message(response)
      response.body&.dig("error", "message") || response.reason_phrase.to_s
    rescue
      ""
    end
  end
end
