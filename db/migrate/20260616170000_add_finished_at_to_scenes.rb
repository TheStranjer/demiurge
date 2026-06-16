# frozen_string_literal: true

class AddFinishedAtToScenes < ActiveRecord::Migration[8.1]
  def change
    add_column :scenes, :finished_at, :datetime
  end
end
