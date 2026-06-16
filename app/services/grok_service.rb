# frozen_string_literal: true

require "net/http"
require "json"

class GrokService
  ENDPOINT = URI("https://api.x.ai/v1/chat/completions").freeze
  MODEL = "grok-4.3"

  def self.call(...)
    new(...).call
  end

  def initialize(grokable:, messages:, tools: [], tool_choice: nil)
    @grokable = grokable
    @messages = messages
    @tools = tools
    @tool_choice = tool_choice
  end

  def call
    payload = build_payload
    http_response = dispatch(payload)
    body = parse_body(http_response)
    record(payload, body, http_response.code.to_i)
    body
  end

  private

  attr_reader :grokable, :messages, :tools, :tool_choice

  def build_payload
    payload = { model: MODEL, messages: messages }
    payload[:tools] = tools if tools.present?
    payload[:tool_choice] = tool_choice if tool_choice.present?
    payload
  end

  def dispatch(payload)
    request = Net::HTTP::Post.new(ENDPOINT)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{api_key}"
    request.body = payload.to_json

    Net::HTTP.start(ENDPOINT.hostname, ENDPOINT.port, use_ssl: true) do |http|
      http.request(request)
    end
  end

  def record(payload, body, status)
    GrokCall.create!(grokable: grokable, payload: payload, response: body, status: status)
  end

  def parse_body(http_response)
    JSON.parse(http_response.body)
  rescue JSON::ParserError
    nil
  end

  def api_key
    ENV.fetch("XAI_API_KEY", nil)
  end
end
