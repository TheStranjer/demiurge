# frozen_string_literal: true

class Scene < ApplicationRecord
  PLAY_MODES = %w[player narrator].freeze

  belongs_to :world
  belongs_to :user
  belongs_to :character

  validates :premise, presence: true
  validates :end_trigger, presence: true
  validates :play_mode, inclusion: { in: PLAY_MODES }

  validate :character_belongs_to_world

  private

  def character_belongs_to_world
    return if character.blank? || world.blank?
    return if character.world_id == world_id

    errors.add(:character, :inclusion)
  end
end
