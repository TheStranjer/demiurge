# frozen_string_literal: true

class CreateWorlds < ActiveRecord::Migration[8.1]
  def change
    create_table :worlds do |t|
      t.string :title, null: false
      t.text :core_concept, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
