# frozen_string_literal: true

module SceneNarration
  class Prompt
    def initialize(event)
      @event = event
      @scene = event.scene
    end

    def base_messages
      [system_message] + history_messages + [current_directive_message]
    end

    def validation_messages(prose)
      [
        { role: "system", content: validation_instructions },
        { role: "user", content: roll_summary },
        { role: "user", content: "Prose to validate:\n#{prose}" },
      ]
    end

    def roll_summary
      lines = @event.roll_results.includes(:roll_table).map do |result|
        "- #{result.roll_table.description} => rolled #{result.roll_result} (#{result.result})"
      end
      lines.any? ? "Roll results so far:\n#{lines.join("\n")}" : "No rolls have been made yet."
    end

    private

    attr_reader :scene

    def system_message
      blocks = [world_block, characters_block, previous_scenes_block, scene_block, tables_block, instructions]
      { role: "system", content: blocks.compact.join("\n\n") }
    end

    def previous_scenes_block
      summaries = scene.previous_summaries
      return nil if summaries.empty?

      lines = summaries.map { |summary| "- #{summary}" }
      "Summaries of previous scenes:\n#{lines.join("\n")}"
    end

    def history_messages
      scene.events.chronological.where.not(id: @event.id).where(status: "complete").flat_map do |event|
        messages = [{ role: "user", content: directive_text(event) }]
        messages << { role: "assistant", content: event.prose } if event.prose.present?
        messages
      end
    end

    def current_directive_message
      { role: "user", content: directive_text(@event) }
    end

    def directive_text(event)
      if event.action_type == "force_act"
        "Force the main character (#{scene.character.name}) to act. #{event.directive}".strip
      else
        "The following happens in the scene: #{event.directive}".strip
      end
    end

    def world_block
      "World: #{scene.world.title}\n#{scene.world.core_concept}"
    end

    def characters_block
      lines = scene.present_characters.map { |character| character_line(character) }
      "Characters in the scene:\n#{lines.join("\n")}"
    end

    def character_line(character)
      stats = Character::STATS.map { |stat| "#{stat} #{character.public_send(stat)}" }.join(", ")
      "- #{character.name} (#{character.sex}): #{stats}"
    end

    def scene_block
      "Premise: #{scene.premise}\n\nEnd-scene trigger: #{scene.end_trigger}"
    end

    def tables_block
      tables = RollTable.order(:id).map { |table| "- ##{table.id}: #{table.description}" }
      tables.any? ? "Available roll tables:\n#{tables.join("\n")}" : "No roll tables exist yet."
    end

    def instructions
      "You are the narrator of this scene. You must roll on at least one roll table before describing " \
        "anything. Only write prose that follows from the roll results. Use the provided tools; do not " \
        "answer in plain text."
    end

    def validation_instructions
      "You are a strict validator. Given the roll results and the prose, decide whether the prose " \
        "plausibly follows from the roll results. Call validate_result with your verdict."
    end
  end
end
