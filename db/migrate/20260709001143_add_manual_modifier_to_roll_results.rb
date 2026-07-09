# frozen_string_literal: true

class AddManualModifierToRollResults < ActiveRecord::Migration[8.1]
  def change
    add_column :roll_results, :manual_modifier, :integer, default: 0, null: false
  end
end
