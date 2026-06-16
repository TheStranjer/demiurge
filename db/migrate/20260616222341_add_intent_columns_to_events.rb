# frozen_string_literal: true

class AddIntentColumnsToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :intent, :text
    add_column :events, :suggested_roll_table_ids, :integer, array: true, null: false, default: []
  end
end
