# frozen_string_literal: true

class AddSuggestedDefenderToEvents < ActiveRecord::Migration[8.1]
  def change
    add_reference :events, :suggested_defender, foreign_key: { to_table: :characters }, null: true
  end
end
