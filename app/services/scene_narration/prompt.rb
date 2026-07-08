# frozen_string_literal: true

module SceneNarration
  class Prompt
    def initialize(event)
      @event = event
      @scene = event.scene
    end

    def intent_messages
      [intent_system_message] + history_messages + [situation_message]
    end

    def narration_messages
      [narration_system_message] + history_messages + [resolution_message]
    end

    def intent_validation_messages(intent)
      [
        { role: "system", content: intent_validation_instructions },
        { role: "user", content: existing_characters_summary },
        { role: "user", content: "The player declared this intent for #{scene.character.name}:\n#{intent}" },
      ]
    end

    def validation_messages(prose)
      [
        { role: "system", content: validation_instructions },
        { role: "user", content: roll_summary },
        { role: "user", content: existing_characters_summary },
        { role: "user", content: "Prose to validate:\n#{prose}" },
      ]
    end

    def roll_summary
      lines = roll_lines
      lines.any? ? "Roll results so far:\n#{lines.join("\n")}" : "No rolls have been made yet."
    end

    def existing_characters_summary
      names = scene.world.characters.order(:id).pluck(:name)
      return "No characters exist yet." if names.empty?

      "The only characters that exist are:\n#{names.map { |name| "- #{name}" }.join("\n")}"
    end

    private

    attr_reader :scene

    def intent_system_message
      blocks = [world_block, characters_block, previous_scenes_block, scene_block, tables_block, intent_instructions]
      { role: "system", content: blocks.compact.join("\n\n") }
    end

    def narration_system_message
      blocks = [world_block, characters_block, previous_scenes_block, scene_block, narration_instructions]
      { role: "system", content: blocks.compact.join("\n\n") }
    end

    def previous_scenes_block
      summaries = scene.previous_summaries
      return nil if summaries.empty?

      "Summaries of previous scenes:\n#{summaries.map { |summary| "- #{summary}" }.join("\n")}"
    end

    def history_messages
      completed_events.flat_map { |event| history_for(event) }
    end

    def completed_events
      scene.events.chronological.where.not(id: @event.id).where(status: "complete")
    end

    def history_for(event)
      messages = []
      messages << { role: "user", content: "Game Master: #{event.directive}" } if event.directive.present?
      messages << { role: "user", content: event.prose } if event.prose.present?
      messages
    end

    def situation_message
      text = @event.directive.presence ||
             "It is #{scene.character.name}'s turn. Decide what they try to do."
      { role: "user", content: text }
    end

    def resolution_message
      parts = ["#{scene.character.name}'s declared intent: #{@event.intent}", roll_outcome_block, narrate_directive]
      { role: "user", content: parts.join("\n\n") }
    end

    def roll_outcome_block
      lines = roll_lines
      return "No roll tables were used, so the attempt simply succeeds." if lines.empty?

      "The Game Master rolled the following:\n#{lines.join("\n")}"
    end

    def narrate_directive
      "Narrate what actually happens, consistent with these results. Use the prose tool, or end_scene if the " \
        "scene's end trigger is now met."
    end

    def roll_lines
      @event.roll_results.includes(:roll_table).map { |result| roll_line(result) }
    end

    def roll_line(result)
      descriptions = result.modifier_descriptions
      math = descriptions.any? ? " #{descriptions.join(" ")} = #{result.modified_roll_result}" : ""
      "- #{result.roll_table.description} => rolled #{result.roll_result}#{math} (#{result.result})"
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
      "Premise Of Current Scene: #{scene.premise}\n\nEnd-scene trigger: #{scene.end_trigger}"
    end

    def tables_block
      tables = scene.world.roll_tables.library.order(:id).map { |table| "- ##{table.id}: #{table.description}" }
      return ExampleTable::GUIDANCE if tables.empty?

      header = "Reusable library tables. Reuse a fitting one by its id instead of proposing a duplicate:"
      "#{header}\n#{tables.join("\n")}"
    end

    def intent_instructions
      "You are playing #{scene.character.name} in this scene. Decide what your character attempts to do this " \
        "turn and call declare_intent. Your character is always reaching for something — they act in order to change " \
        "their situation, so every intent has two parts and you must give both: the action — what your character " \
        "concretely does or says — and the goal — the effect they are trying to produce by doing it. Do not stop " \
        "at what they say; state what they want it to make happen: not 'I tell the guard the bridge is out' but " \
        "'I try to turn the guard back by warning them the bridge is out.' Name the outcome they pursue — " \
        "persuading someone, prying loose a secret, intimidating a rival, solving a puzzle — but state it as the " \
        "attempt, never the outcome, and never as something that has already happened; the Game Master, not you, " \
        "decides whether and how it resolves. Because the outcome is uncertain, by default give the Game Master " \
        "something to roll: suggest existing roll tables by id and/or propose new ones to adjudicate the attempt, " \
        "reaching for an existing table first and proposing a new one only when none fits. Roll tables should be " \
        "reusable, not specific to one person or moment. Skip this only for a pure dialogue beat with no real " \
        "chance of failure where the outcome doesn't matter. Never declare another character's actions, decisions, " \
        "or fate, and never assume your own attempt has already succeeded. Use the provided tool; do not answer " \
        "in plain text."
    end

    def narration_instructions
      "You are narrating the outcome of #{scene.character.name}'s attempt, using the roll results the Game " \
        "Master produced. Describe what actually happens, consistent with those rolls — a poor roll means the " \
        "attempt falters or fails. Only feature characters who already exist. Never dictate another character's " \
        "actions, decisions, or fate. Use the prose tool, or end_scene when the scene's end trigger is " \
        "satisfied; do not answer in plain text."
    end

    def intent_validation_instructions
      "You are a strict validator checking a player's declared intent. An intent is both what the character " \
        "attempts and the goal they pursue by it, so a goal aimed at another character — to persuade, deceive, " \
        "intimidate, or otherwise move them — is expected and valid; never reject an intent merely for naming " \
        "such a goal. Call validate_result with follows: false only if the intent godmods by treating an " \
        "uncertain outcome as already settled: it states another character's actual response, decision, or fate " \
        "as fact, or asserts its own outcome as already succeeded instead of merely attempted. Otherwise call " \
        "follows: true. When follows is false, the reason must explain exactly what is wrong so the player can " \
        "restate it as a pure attempt."
    end

    def validation_instructions
      "You are a strict validator. Call validate_result with follows: false if ANY of these checks fail, " \
        "and follows: true only when they all pass. (1) The prose plausibly follows from the roll results. " \
        "(2) Every character named in the prose is one of the characters that exist (listed above); a " \
        "character invented out of nowhere fails this check. (3) Nobody godmods: a character may decide " \
        "only their own actions and must never dictate another character's actions, decisions, or fate. " \
        "When follows is false, the reason must name the specific failing check and quote or describe the " \
        "offending part of the prose so it can be fixed."
    end
  end
end
