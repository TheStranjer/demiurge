# frozen_string_literal: true

module SceneNarration
  class ToolRunner
    Result = Struct.new(:signal, :content, :summary, keyword_init: true)

    HANDLERS = %w[declare_intent prose end_scene].freeze

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

    def declare_intent(arguments)
      intent = arguments["intent"].to_s
      suggested_ids = Array(arguments["suggested_roll_table_ids"]).map(&:to_i) & library_ids
      created = Array(arguments["new_tables"]).map { |definition| create_suggestion(definition) }
      event.update!(intent: intent, suggested_roll_table_ids: suggested_ids)
      Result.new(signal: :intent,
                 content: { intent: intent, suggested_roll_table_ids: suggested_ids,
                            new_table_ids: created.map(&:id), }.to_json,)
    end

    def prose(arguments)
      Result.new(signal: :prose, content: arguments["text"].to_s)
    end

    def end_scene(arguments)
      Result.new(signal: :end_scene, content: arguments["text"].to_s, summary: arguments["summary"].to_s)
    end

    def create_suggestion(definition)
      attributes = definition.slice("description", "denomination", "quantity", "possible_results",
                                    "contested", "entity_modifiers", "defender_modifiers",)
      scene.world.roll_tables.create!(attributes.merge(suggestion: true, event: event))
    end

    def library_ids
      scene.world.roll_tables.library.pluck(:id)
    end
  end
end
