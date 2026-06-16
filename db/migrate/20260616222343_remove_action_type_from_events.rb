# frozen_string_literal: true

class RemoveActionTypeFromEvents < ActiveRecord::Migration[8.1]
  def change
    remove_column :events, :action_type, :string, null: false
  end
end
