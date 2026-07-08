# frozen_string_literal: true

class AddSceneAndCharactersToRollResults < ActiveRecord::Migration[8.1]
  def change
    add_reference :roll_results, :scene, foreign_key: true, null: true
    add_reference :roll_results, :character, foreign_key: true, null: true
    add_reference :roll_results, :defender, foreign_key: { to_table: :characters }, null: true
  end
end
