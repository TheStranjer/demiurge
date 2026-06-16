# frozen_string_literal: true

class Scene < ApplicationRecord
  PLAY_MODES = %w[player narrator].freeze

  belongs_to :world
  belongs_to :user
  belongs_to :character

  has_many :events, dependent: :destroy
  has_many :scene_presences, dependent: :destroy

  validates :premise, presence: true
  validates :end_trigger, presence: true
  validates :play_mode, inclusion: { in: PLAY_MODES }

  validate :character_belongs_to_world

  def narrator_mode?
    play_mode == "narrator"
  end

  def finished?
    finished_at.present?
  end

  def finish!
    update!(finished_at: Time.current) unless finished?
  end

  def present_characters
    others = scene_presences.present.includes(:character).map(&:character)
    ([character] + others).uniq
  end

  private

  def character_belongs_to_world
    return if character.blank? || world.blank?
    return if character.world_id == world_id

    errors.add(:character, :inclusion)
  end
end
