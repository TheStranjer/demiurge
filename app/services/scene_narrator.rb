# frozen_string_literal: true

require "json"

class SceneNarrator
  MAX_TURNS = 12
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
    @messages = @prompt.base_messages
  end

  def call
    reset_event
    return :failed unless forced_roll?

    narrate_until_valid
  end

  private

  attr_reader :event, :scene, :tools, :prompt, :runner, :messages

  def reset_event
    event.roll_results.destroy_all
    event.update!(prose: nil, validated: nil)
  end

  def forced_roll?
    event.update!(status: "rolling")
    message = request(tools.roll_tools, tool_choice: "required")
    return false if message.nil?

    process_tool_calls(message)
    event.roll_results.exists?
  end

  def main_loop
    event.update!(status: "narrating")
    MAX_TURNS.times do
      message = request(tools.full_tools)
      return nil if message.nil?

      terminal = process_tool_calls(message)
      return terminal if terminal
    end
    nil
  end

  def narrate_until_valid
    MAX_VALIDATION_ATTEMPTS.times do
      terminal = main_loop
      return :failed if terminal.nil?

      event.update!(status: "validating", prose: terminal.content, ended_scene: terminal.signal == :end_scene)
      reason = validation_failure(terminal.content)
      return complete(terminal) if reason.nil?

      feed_back_validation_failure(reason)
    end
    :unvalidated
  end

  def complete(terminal)
    scene.finish!(summary: terminal.summary) if event.ended_scene
    event.update!(status: "complete")
    :complete
  end

  def validation_failure(prose)
    body = GrokService.call(grokable: event, messages: prompt.validation_messages(prose),
                            tools: tools.validation_tools, tool_choice: "required",)
    call = first_tool_call(body)
    return "The validator did not return a result." if call.nil?

    arguments = parse_arguments(call.dig("function", "arguments"))
    follows = arguments["follows"] == true
    event.update!(validated: follows)
    return nil if follows

    arguments["reason"].to_s.presence || "The prose failed validation."
  end

  def feed_back_validation_failure(reason)
    messages << {
      role: "user",
      content: "A strict validator rejected your previous narration. Reason:\n#{reason}\n\n" \
               "Narrate again with the tools, fixing this problem. The new prose must follow from the " \
               "roll results, feature only characters who exist, and never dictate another character's " \
               "actions, decisions, or fate.",
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
    terminal = nil
    Array(message["tool_calls"]).each do |call|
      result = run_tool_call(call)
      append_tool_result(call, result)
      terminal = result if %i[prose end_scene].include?(result.signal)
    end
    terminal
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
