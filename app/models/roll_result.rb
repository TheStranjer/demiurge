# frozen_string_literal: true

class RollResult < ApplicationRecord
  belongs_to :roll_table
  belongs_to :entity, polymorphic: true
  belongs_to :entity_defender, polymorphic: true, optional: true

  validates :roll_result, presence: true, numericality: { only_integer: true }
  validates :roll_result_defender, numericality: { only_integer: true }, allow_nil: true

  def contested?
    roll_result_defender.present?
  end

  def result
    roll_table&.result_for(roll_result)
  end
end
