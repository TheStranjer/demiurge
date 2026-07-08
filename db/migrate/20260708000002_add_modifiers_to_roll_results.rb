# frozen_string_literal: true

class AddModifiersToRollResults < ActiveRecord::Migration[8.1]
  def change
    add_column :roll_results, :modifiers, :jsonb, null: false, default: []
  end
end
