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

    STAT_MODIFIERS = {
      type: "array",
      items: { type: "string", enum: Character::STATS.map(&:to_s) },
    }.freeze

    NEW_TABLE = {
      type: "object",
      properties: {
        description: { type: "string" },
        denomination: { type: "integer" },
        quantity: { type: "integer" },
        contested: {
          type: "boolean",
          description: "True when another character resists the attempt (deceiving, grappling); false for " \
                       "uncontested feats like climbing a wall.",
        },
        entity_modifiers: STAT_MODIFIERS.merge(
          description: "Stats the acting character adds to the roll (e.g. finesse when deceiving). May be empty.",
        ),
        defender_modifiers: STAT_MODIFIERS.merge(
          description: "Stats the resisting character subtracts from the roll (e.g. awareness). Empty when " \
                       "uncontested.",
        ),
        possible_results: { type: "array", items: RESULT_ROW },
      },
      required: %w[description denomination quantity contested entity_modifiers defender_modifiers possible_results],
    }.freeze

    SUGGESTED_IDS_HINT = "Ids of existing library tables (listed in the system prompt) to reuse for this attempt. " \
                         "Always prefer reusing a table that already fits over proposing a new one."

    NEW_TABLES_HINT = "Propose a new table ONLY when no existing library table fits the attempt. Never restate a " \
                      "table that already exists — reuse it through suggested_roll_table_ids instead. New tables " \
                      "must be reusable, not tied to one character or moment."

    DEFENDER_HINT = "When the attempt is contested (another character resists), name the character most likely to " \
                    "resist it so the Game Master can default the defender for those rolls. Leave empty for wholly " \
                    "uncontested attempts."

    def initialize(scene, event = nil)
      @scene = scene
      @event = event
    end

    def intent_tools
      [declare_intent_tool]
    end

    def narration_tools
      [prose_tool, end_scene_tool]
    end

    def validation_tools
      [function("validate_result",
                "Return whether the content is free of godmodding (one character may decide only their own " \
                "actions and must never dictate another character's actions, decisions, or fate) and otherwise " \
                "valid. When follows is false, reason must spell out exactly what is wrong so it can be fixed.",
                { follows: { type: "boolean" },
                  reason: { type: "string",
                            description: "Why validation failed. Leave empty when follows is true.", }, },
                %w[follows reason],)]
    end

    private

    attr_reader :scene, :event

    def declare_intent_tool
      function("declare_intent",
               "State what #{scene.character.name} is trying to do this turn. Declare only the intent — the " \
               "attempt — and never its outcome; the Game Master decides how it resolves. Optionally suggest " \
               "existing roll tables by id and/or propose brand new roll tables for the Game Master to use. " \
               "Never dictate another character's actions, decisions, or fate.",
               intent_properties, %w[intent],)
    end

    def intent_properties
      ids = library_table_ids
      item = ids.any? ? { type: "integer", enum: ids } : { type: "integer" }
      properties = {
        intent: { type: "string" },
        suggested_roll_table_ids: { type: "array", items: item, description: SUGGESTED_IDS_HINT },
        new_tables: { type: "array", items: NEW_TABLE, description: NEW_TABLES_HINT },
      }
      names = defender_names
      properties[:defender_name] = { type: "string", enum: names, description: DEFENDER_HINT } if names.any?
      properties
    end

    def library_table_ids
      scene.world.roll_tables.library.order(:id).pluck(:id)
    end

    def defender_names
      scene.present_characters.reject { |character| character.id == scene.character_id }.map(&:name)
    end

    def prose_tool
      function("prose", "Describe what happens, consistent with the roll results.",
               { text: { type: "string" } }, %w[text],)
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
