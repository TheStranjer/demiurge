# frozen_string_literal: true

module SceneNarration
  class GmAdjudication
    def self.call(...)
      new(...).call
    end

    def initialize(event, tables)
      @event = event
      @scene = event.scene
      @tables = Array(tables)
    end

    def call
      ActiveRecord::Base.transaction do
        rolls = included_tables.filter_map { |table| build_roll(table) }
        @event.proposed_roll_tables.destroy_all
        roll_all(rolls)
        @event.update!(status: "rolled", attempts: 0)
      end
      true
    end

    private

    def included_tables
      @tables.select { |table| truthy?(table["include"]) }
    end

    def build_roll(table)
      resolved = resolve_table(table)
      return nil if resolved.nil?

      { table: resolved, defender: defender_for(table, resolved) }
    end

    def defender_for(table, resolved)
      return nil unless resolved.contested?

      id = table["defender_id"]
      return nil if id.blank? || id.to_i == @scene.character_id

      @scene.world.characters.find_by(id: id)
    end

    def ensure_present(character)
      return if character.nil? || character.id == @scene.character_id

      presence = @scene.scene_presences.find_or_initialize_by(character: character)
      presence.departed_at = nil
      presence.save!
    end

    def resolve_table(table)
      if table["source"] == "existing"
        @scene.world.roll_tables.library.find_by(id: table["roll_table_id"])
      else
        upsert_draft(table)
      end
    end

    def upsert_draft(table)
      attributes = draft_attributes(table)
      existing = library_match(attributes[:description])
      return existing if existing

      promote_or_create(attributes, table["origin_suggestion_id"])
    end

    def library_match(description)
      signature = RollTable.normalize_description(description)
      @scene.world.roll_tables.library.detect { |candidate| candidate.signature == signature }
    end

    def promote_or_create(attributes, origin_id)
      origin = origin_suggestion(origin_id)
      if origin
        origin.update!(attributes.merge(suggestion: false, event: nil))
        origin
      else
        @scene.world.roll_tables.create!(attributes.merge(suggestion: false))
      end
    end

    def draft_attributes(table)
      {
        description: table["description"].to_s,
        denomination: table["denomination"].to_i,
        quantity: (table["quantity"].presence || 1).to_i,
        contested: truthy?(table["contested"]) || false,
        entity_modifiers: Array(table["entity_modifiers"]),
        defender_modifiers: Array(table["defender_modifiers"]),
        possible_results: result_rows(table["results"]),
      }
    end

    def result_rows(results)
      rows = results.respond_to?(:values) ? results.values : Array(results)
      rows.filter_map { |row| result_row(row) }
    end

    def result_row(row)
      return nil if row["result"].blank? && row["min"].blank? && row["max"].blank?

      { "min" => integer_or_nil(row["min"]), "max" => integer_or_nil(row["max"]), "result" => row["result"].to_s }
    end

    def origin_suggestion(id)
      return nil if id.blank?

      @event.proposed_roll_tables.find_by(id: id)
    end

    def roll_all(rolls)
      rolls.each do |roll|
        table = roll[:table]
        ensure_present(roll[:defender])
        @event.roll_results.create!(roll_table: table, roll_result: table.roll,
                                    scene: @scene, character: @scene.character, defender: roll[:defender],)
      end
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def integer_or_nil(value)
      return nil if value.blank?

      Integer(value, exception: false)
    end
  end
end
