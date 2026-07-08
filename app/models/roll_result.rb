# frozen_string_literal: true

class RollResult < ApplicationRecord
  ENTITY_ROLE = "entity"
  DEFENDER_ROLE = "defender"

  belongs_to :roll_table
  belongs_to :entity, polymorphic: true
  belongs_to :entity_defender, polymorphic: true, optional: true
  belongs_to :scene, optional: true
  belongs_to :character, optional: true
  belongs_to :defender, class_name: "Character", optional: true

  before_create :capture_modifiers

  validates :roll_result, presence: true, numericality: { only_integer: true }
  validates :roll_result_defender, numericality: { only_integer: true }, allow_nil: true

  def contested?
    roll_result_defender.present?
  end

  def applied_modifiers
    modifiers.presence || computed_modifiers
  end

  def modifier_total
    applied_modifiers.sum { |modifier| signed_value(modifier) }
  end

  def modified_roll_result
    roll_result.to_i + modifier_total
  end

  def modifier_descriptions
    applied_modifiers.map { |modifier| modifier_description(modifier) }
  end

  def result
    roll_table&.result_for(modified_roll_result)
  end

  private

  def modifier_description(modifier)
    operator = modifier["role"] == DEFENDER_ROLE ? "-" : "+"
    "#{operator} #{modifier["stat"]} (#{signed_label(modifier["value"])})"
  end

  def signed_label(value)
    value = value.to_i
    value.negative? ? value.to_s : "+#{value}"
  end

  def capture_modifiers
    self.modifiers = computed_modifiers if modifiers.blank?
  end

  def computed_modifiers
    return [] if roll_table.nil?

    modifier_entries(character, roll_table.entity_modifiers, ENTITY_ROLE) +
      modifier_entries(defender, roll_table.defender_modifiers, DEFENDER_ROLE)
  end

  def modifier_entries(subject, stats, role)
    return [] if subject.nil?

    Array(stats).filter_map do |stat|
      next unless subject.respond_to?(stat)

      { "role" => role, "stat" => stat.to_s, "value" => subject.public_send(stat).to_i }
    end
  end

  def signed_value(modifier)
    value = modifier["value"].to_i
    modifier["role"] == DEFENDER_ROLE ? -value : value
  end
end
