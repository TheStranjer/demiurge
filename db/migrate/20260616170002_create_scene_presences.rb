# frozen_string_literal: true

class CreateScenePresences < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_presences do |t|
      t.references :scene, null: false, foreign_key: true
      t.references :character, null: false, foreign_key: true
      t.datetime :departed_at

      t.timestamps
    end

    add_index :scene_presences, %i[scene_id character_id], unique: true, if_not_exists: true
  end
end
