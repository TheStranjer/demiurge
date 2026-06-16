# frozen_string_literal: true

class CreateCharacters < ActiveRecord::Migration[8.1]
  STATS = %i[
    strength dexterity endurance
    intelligence awareness willpower
    charisma finesse tact
  ].freeze

  def change
    create_table :characters do |t|
      t.string :name, null: false
      t.string :sex, null: false
      t.boolean :non_player_character, null: false, default: false
      t.references :world, null: false, foreign_key: true

      STATS.each { |stat| t.integer stat, null: false }

      t.timestamps
    end
  end
end
