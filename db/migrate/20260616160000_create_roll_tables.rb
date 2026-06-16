# frozen_string_literal: true

class CreateRollTables < ActiveRecord::Migration[8.1]
  def change
    create_table :roll_tables do |t|
      t.integer :denomination, null: false
      t.integer :quantity, null: false, default: 1
      t.jsonb :possible_results, null: false, default: []
      t.text :description, null: false

      t.timestamps
    end
  end
end
