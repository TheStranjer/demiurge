# frozen_string_literal: true

class Event < ApplicationRecord
  STATUSES = %w[pending declaring awaiting_gm rolled narrating validating complete failed].freeze

  belongs_to :scene
  belongs_to :suggested_defender, class_name: "Character", optional: true
  has_many :roll_results, as: :entity, dependent: :destroy
  has_many :grok_calls, as: :grokable, dependent: :destroy
  has_many :proposed_roll_tables, -> { where(suggestion: true) }, class_name: "RollTable",
                                                                  dependent: :destroy, inverse_of: :event

  validates :status, inclusion: { in: STATUSES }

  scope :chronological, -> { order(:created_at) }

  def complete?
    status == "complete"
  end

  def failed?
    status == "failed"
  end

  def awaiting_gm?
    status == "awaiting_gm"
  end

  def pending?
    !complete? && !failed?
  end
end
