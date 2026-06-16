# frozen_string_literal: true

class AddSummaryToScenes < ActiveRecord::Migration[8.1]
  def change
    add_column :scenes, :summary, :text
  end
end
