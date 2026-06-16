# frozen_string_literal: true

class CreateGrokCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :grok_calls do |t|
      t.references :grokable, polymorphic: true, null: false
      t.jsonb :payload, null: false
      t.jsonb :response
      t.integer :status

      t.timestamps
    end
  end
end
