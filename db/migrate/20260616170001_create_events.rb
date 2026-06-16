# frozen_string_literal: true

class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :scene, null: false, foreign_key: true
      t.string :action_type, null: false
      t.text :directive
      t.text :prose
      t.boolean :ended_scene, null: false, default: false
      t.boolean :validated
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0

      t.timestamps
    end
  end
end
