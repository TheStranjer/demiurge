# frozen_string_literal: true

module SceneNarration
  class ToolRunner
    Result = Struct.new(:signal, :content, :summary, keyword_init: true)

    HANDLERS = %w[roll_tables create_roll_table create_character character_arrive character_depart
                  prose end_scene].freeze

    def initialize(event)
      @event = event
      @scene = event.scene
    end

    def run(name, arguments)
      return Result.new(signal: :continue, content: "Unknown tool: #{name}") unless HANDLERS.include?(name)

      send(name, arguments)
    end

    private

    attr_reader :event, :scene

    def prose(arguments)
      continue_with_prose(arguments, :prose)
    end

    def end_scene(arguments)
      Result.new(signal: :end_scene, content: arguments["text"].to_s, summary: arguments["summary"].to_s)
    end

    def roll_tables(arguments)
      ids = Array(arguments["roll_table_ids"])
      rolled = RollTable.where(id: ids).map { |table| record_roll(table) }
      Result.new(signal: :continue, content: rolled.to_json)
    end

    def create_roll_table(arguments)
      table = RollTable.create!(arguments.slice("description", "denomination", "quantity", "possible_results"))
      Result.new(signal: :continue, content: record_roll(table).merge(roll_table_id: table.id).to_json)
    end

    def record_roll(table)
      value = table.roll
      event.roll_results.create!(roll_table: table, roll_result: value)
      { roll_table_id: table.id, description: table.description, roll: value, result: table.result_for(value) }
    end

    def create_character(arguments)
      attributes = arguments.slice("name", "sex", "non_player_character", *Character::STATS.map(&:to_s))
      character = scene.world.characters.create!(attributes)
      Result.new(signal: :continue, content: { character_id: character.id, name: character.name }.to_json)
    end

    def character_arrive(arguments)
      presence = scene.scene_presences.find_or_initialize_by(character_id: arguments["character_id"])
      presence.update!(departed_at: nil)
      Result.new(signal: :continue, content: "#{presence.character.name} arrives.")
    end

    def character_depart(arguments)
      presence = scene.scene_presences.present.find_by(character_id: arguments["character_id"])
      presence&.depart!
      Result.new(signal: :continue, content: "Character #{arguments["character_id"]} departs.")
    end

    def continue_with_prose(arguments, signal)
      Result.new(signal: signal, content: arguments["text"].to_s)
    end
  end
end
