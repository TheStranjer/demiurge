# frozen_string_literal: true

class AddModifiersAndContestedToRollTables < ActiveRecord::Migration[8.1]
  def change
    change_table :roll_tables, bulk: true do |t|
      t.boolean :contested, null: false, default: false
      t.string :entity_modifiers, array: true, null: false, default: []
      t.string :defender_modifiers, array: true, null: false, default: []
    end
  end
end
