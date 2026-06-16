# frozen_string_literal: true

class CreateRollResults < ActiveRecord::Migration[8.1]
  def change
    create_table :roll_results do |t|
      t.references :roll_table, null: false, foreign_key: true
      t.integer :roll_result, null: false
      t.integer :roll_result_defender
      t.references :entity, polymorphic: true, null: false
      t.references :entity_defender, polymorphic: true, null: true

      t.timestamps
    end
  end
end
