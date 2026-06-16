# frozen_string_literal: true

module SceneNarration
  class ToolDefinitions
    RESULT_ROW = {
      type: "object",
      properties: {
        min: { type: %w[integer null] },
        max: { type: %w[integer null] },
        result: { type: %w[string null] },
      },
      required: %w[min max result],
    }.freeze

    def initialize(scene)
      @scene = scene
    end

    def roll_tools
      [roll_tables_tool, create_roll_table_tool]
    end

    def full_tools
      tools = roll_tools + [prose_tool, create_character_tool]
      tools << character_arrive_tool if absent_character_ids.any?
      tools << character_depart_tool if present_character_ids.any?
      tools + [end_scene_tool]
    end

    def validation_tools
      [function("validate_result", "Return whether the prose follows from the roll results.",
                { follows: { type: "boolean" } }, %w[follows],)]
    end

    private

    attr_reader :scene

    def roll_tables_tool
      ids = RollTable.order(:id).pluck(:id)
      item = ids.any? ? { type: "integer", enum: ids } : { type: "integer" }
      function("roll_tables", "Roll on one or more existing roll tables by id.",
               { roll_table_ids: { type: "array", items: item } }, %w[roll_table_ids],)
    end

    def create_roll_table_tool
      function("create_roll_table", "Create a brand new roll table and immediately roll on it.", {
                 description: { type: "string" },
                 denomination: { type: "integer" },
                 quantity: { type: "integer" },
                 possible_results: { type: "array", items: RESULT_ROW },
               }, %w[description denomination quantity possible_results],)
    end

    def prose_tool
      function("prose", "Describe to the player what happens. Must follow from the roll results.",
               { text: { type: "string" } }, %w[text],)
    end

    def create_character_tool
      function("create_character", "Create a new character in the world.",
               character_properties, %w[name sex non_player_character] + Character::STATS.map(&:to_s),)
    end

    def character_arrive_tool
      function("character_arrive", "Bring a character into the scene.",
               { character_id: { type: "integer", enum: absent_character_ids } }, %w[character_id],)
    end

    def character_depart_tool
      function("character_depart", "Remove a character who has left the scene.",
               { character_id: { type: "integer", enum: present_character_ids } }, %w[character_id],)
    end

    def end_scene_tool
      function("end_scene", "Describe what happens and end the scene. Must follow from the roll results.",
               { text: { type: "string" } }, %w[text],)
    end

    def character_properties
      base = {
        name: { type: "string" },
        sex: { type: "string", enum: Character::SEXES },
        non_player_character: { type: "boolean" },
      }
      base.merge(Character::STATS.index_with { { type: "integer", minimum: -5, maximum: 5 } })
    end

    def absent_character_ids
      scene.world.characters.order(:id).pluck(:id) - present_character_ids
    end

    def present_character_ids
      scene.present_characters.map(&:id)
    end

    def function(name, description, properties, required)
      {
        type: "function",
        function: {
          name: name,
          description: description,
          parameters: { type: "object", properties: properties, required: required },
        },
      }
    end
  end
end
