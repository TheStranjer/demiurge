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

    NEW_TABLE = {
      type: "object",
      properties: {
        description: { type: "string" },
        denomination: { type: "integer" },
        quantity: { type: "integer" },
        possible_results: { type: "array", items: RESULT_ROW },
      },
      required: %w[description denomination quantity possible_results],
    }.freeze

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
      {
        intent: { type: "string" },
        suggested_roll_table_ids: { type: "array", items: item },
        new_tables: { type: "array", items: NEW_TABLE },
      }
    end

    def library_table_ids
      scene.world.roll_tables.library.order(:id).pluck(:id)
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
