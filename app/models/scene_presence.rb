# frozen_string_literal: true

class ScenePresence < ApplicationRecord
  belongs_to :scene
  belongs_to :character

  validates :character_id, uniqueness: { scope: :scene_id }

  validate :character_belongs_to_world

  scope :present, -> { where(departed_at: nil) }

  def depart!
    update!(departed_at: Time.current) if departed_at.nil?
  end

  private

  def character_belongs_to_world
    return if character.blank? || scene.blank?
    return if character.world_id == scene.world_id

    errors.add(:character, :inclusion)
  end
end
