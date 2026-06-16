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

    def initialize(scene, event = nil)
      @scene = scene
      @event = event
    end

    def roll_tools
      [roll_tables_tool, create_roll_table_tool].compact
    end

    def full_tools
      tools = roll_tools + [prose_tool, create_character_tool]
      tools << character_arrive_tool if absent_character_ids.any?
      tools << character_depart_tool if present_character_ids.any?
      tools + [end_scene_tool]
    end

    def validation_tools
      [function("validate_result",
                "Return whether the prose follows from the rolls, only features characters that exist, " \
                "and is free of godmodding. When follows is false, reason must spell out exactly which " \
                "check failed and what is wrong so the narrator can fix it.",
                { follows: { type: "boolean" },
                  reason: { type: "string",
                            description: "Why validation failed. Leave empty when follows is true.", }, },
                %w[follows reason],)]
    end

    private

    attr_reader :scene, :event

    def roll_tables_tool
      all_ids = RollTable.order(:id).pluck(:id)
      available = all_ids - rolled_table_ids
      return nil if all_ids.any? && available.empty?

      item = available.any? ? { type: "integer", enum: available } : { type: "integer" }
      function("roll_tables", "Roll on one or more existing roll tables by id. Each table may be rolled " \
                              "only once per action; rolled tables are no longer offered.",
               { roll_table_ids: { type: "array", items: item } }, %w[roll_table_ids],)
    end

    def rolled_table_ids
      event ? event.roll_results.pluck(:roll_table_id) : []
    end

    def create_roll_table_tool
      function("create_roll_table", "Create a brand new roll table and immediately roll on it. The roll table should always be applicable to more than just this specific scene/person; use some amount of abstraction. No table is for one person or situation.", {
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
      function("end_scene", "Describe what happens and end the scene. Must follow from the roll results.", {
                 text: { type: "string" },
                 summary: {
                   type: "string",
                   description: "A concise summary of the whole scene for future narrative context.",
                 },
               }, %w[text summary],)
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
