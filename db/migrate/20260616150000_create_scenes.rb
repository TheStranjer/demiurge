# frozen_string_literal: true

class CreateScenes < ActiveRecord::Migration[8.1]
  def change
    create_table :scenes do |t|
      t.text :premise, null: false
      t.text :end_trigger, null: false
      t.string :play_mode, null: false
      t.references :world, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :character, null: false, foreign_key: true

      t.timestamps
    end
  end
end
