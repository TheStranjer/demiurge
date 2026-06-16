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
        final = included_tables.filter_map { |table| resolve_table(table) }
        @event.proposed_roll_tables.destroy_all
        roll_all(final)
        @event.update!(status: "rolled", attempts: 0)
      end
      true
    end

    private

    def included_tables
      @tables.select { |table| truthy?(table["include"]) }
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
      origin = origin_suggestion(table["origin_suggestion_id"])
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

    def roll_all(tables)
      tables.each do |table|
        @event.roll_results.create!(roll_table: table, roll_result: table.roll)
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
