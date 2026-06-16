# frozen_string_literal: true

class AddWorldAndSuggestionToRollTables < ActiveRecord::Migration[8.1]
  def change
    add_reference :roll_tables, :world, null: false, foreign_key: true
    add_column :roll_tables, :suggestion, :boolean, null: false, default: false
    add_reference :roll_tables, :event, null: true, foreign_key: { on_delete: :nullify }
  end
end
