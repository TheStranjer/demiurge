# frozen_string_literal: true

class RollTable < ApplicationRecord
  RESULT_KEYS = %w[min max result].freeze
  STAT_NAMES = Character::STATS.map(&:to_s).freeze

  belongs_to :world
  belongs_to :event, optional: true
  has_many :roll_results, dependent: :destroy

  scope :suggestions, -> { where(suggestion: true) }
  scope :library, -> { where(suggestion: false) }

  before_validation :normalize_modifiers

  validates :denomination, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :description, presence: true

  validate :possible_results_is_well_formed
  validate :modifiers_reference_known_stats

  def row_for(value)
    possible_results.find { |row| within_bounds?(row, value) }
  end

  def result_for(value)
    entry = row_for(value)
    entry && entry["result"]
  end

  def roll
    Array.new(quantity.to_i) { rand(1..denomination.to_i) }.sum
  end

  def minimum_roll
    quantity.to_i
  end

  def maximum_roll
    quantity.to_i * denomination.to_i
  end

  private

  def normalize_modifiers
    self.entity_modifiers = clean_modifiers(entity_modifiers)
    self.defender_modifiers = clean_modifiers(defender_modifiers)
  end

  def clean_modifiers(values)
    Array(values).map { |value| value.to_s.strip }.compact_blank.uniq
  end

  def modifiers_reference_known_stats
    unknown = (Array(entity_modifiers) + Array(defender_modifiers)).reject { |stat| STAT_NAMES.include?(stat) }
    return if unknown.empty?

    errors.add(:base, "unknown stat modifiers: #{unknown.uniq.join(", ")}")
  end

  def within_bounds?(row, value)
    min = row["min"]
    max = row["max"]
    (min.nil? || value >= min) && (max.nil? || value <= max)
  end

  def possible_results_is_well_formed
    unless possible_results.is_a?(Array) && possible_results.any?
      errors.add(:possible_results, :blank)
      return
    end

    return if possible_results.all? { |row| valid_result_row?(row) }

    errors.add(:possible_results, :invalid)
  end

  def valid_result_row?(row)
    return false unless row.is_a?(Hash)
    return false unless (row.keys - RESULT_KEYS).empty?
    return false unless row["min"].nil? || row["min"].is_a?(Integer)
    return false unless row["max"].nil? || row["max"].is_a?(Integer)

    row.key?("result")
  end
end
