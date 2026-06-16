# frozen_string_literal: true

class Character < ApplicationRecord
  SEXES = %w[male female].freeze

  STAT_GROUPS = {
    "Physical" => %i[strength dexterity endurance],
    "Mental" => %i[intelligence awareness willpower],
    "Social" => %i[charisma finesse tact],
  }.freeze

  STATS = STAT_GROUPS.values.flatten.freeze

  STAT_NUMERICALITY = { only_integer: true, greater_than_or_equal_to: -5, less_than_or_equal_to: 5 }.freeze

  belongs_to :world

  validates :name, presence: true, length: { maximum: 255 }
  validates :sex, inclusion: { in: SEXES }
  validates :non_player_character, inclusion: { in: [true, false] }

  validates(*STATS, presence: true, numericality: STAT_NUMERICALITY)
end
