# frozen_string_literal: true

require "json"

module SceneNarration
  class IntentDeclarer
    MAX_VALIDATION_ATTEMPTS = 3

    def self.call(...)
      new(...).call
    end

    def initialize(event)
      @event = event
      @scene = event.scene
      @tools = SceneNarration::ToolDefinitions.new(@scene, event)
      @prompt = SceneNarration::Prompt.new(event)
      @runner = SceneNarration::ToolRunner.new(event)
      @messages = @prompt.intent_messages
    end

    def call
      event.update!(validated: nil)
      declare_until_valid
    end

    private

    attr_reader :event, :scene, :tools, :prompt, :runner, :messages

    def declare_until_valid
      MAX_VALIDATION_ATTEMPTS.times do
        return :failed unless declared_intent?

        reason = intent_validation_failure(event.intent)
        return await_gm if reason.nil?

        feed_back_validation_failure(reason)
      end
      :failed
    end

    def declared_intent?
      event.proposed_roll_tables.destroy_all
      event.update!(status: "declaring", intent: nil, suggested_roll_table_ids: [])
      message = request(tools.intent_tools, tool_choice: "required")
      return false if message.nil?

      process_tool_calls(message)
      event.reload.intent.present?
    end

    def await_gm
      event.update!(status: "awaiting_gm")
      :awaiting_gm
    end

    def intent_validation_failure(intent)
      body = GrokService.call(grokable: event, messages: prompt.intent_validation_messages(intent),
                              tools: tools.validation_tools, tool_choice: "required",)
      call = first_tool_call(body)
      return "The validator did not return a result." if call.nil?

      arguments = parse_arguments(call.dig("function", "arguments"))
      follows = arguments["follows"] == true
      event.update!(validated: follows)
      return nil if follows

      arguments["reason"].to_s.presence || "The intent failed validation."
    end

    def feed_back_validation_failure(reason)
      messages << {
        role: "user",
        content: "A strict validator rejected your previous intent. Reason:\n#{reason}\n\n" \
                 "Declare the intent again with the tool, fixing this problem. State only what your " \
                 "character attempts; never decide the outcome or another character's actions, decisions, or fate.",
      }
    end

    def request(call_tools, tool_choice: nil)
      body = GrokService.call(grokable: event, messages: messages, tools: call_tools, tool_choice: tool_choice)
      message = body&.dig("choices", 0, "message")
      return nil if message.nil?

      messages << message
      message
    end

    def process_tool_calls(message)
      Array(message["tool_calls"]).each do |call|
        result = run_tool_call(call)
        append_tool_result(call, result)
      end
    end

    def run_tool_call(call)
      name = call.dig("function", "name")
      runner.run(name, parse_arguments(call.dig("function", "arguments")))
    end

    def append_tool_result(call, result)
      messages << { role: "tool", tool_call_id: call["id"], content: result.content.to_s }
    end

    def first_tool_call(body)
      message = body&.dig("choices", 0, "message")
      message && Array(message["tool_calls"]).first
    end

    def parse_arguments(raw)
      return raw if raw.is_a?(Hash)

      JSON.parse(raw.to_s)
    rescue JSON::ParserError
      {}
    end
  end
end
