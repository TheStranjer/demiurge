# frozen_string_literal: true

class Event < ApplicationRecord
  ACTION_TYPES = %w[force_act narrate].freeze
  STATUSES = %w[pending rolling narrating validating complete failed].freeze

  belongs_to :scene
  has_many :roll_results, as: :entity, dependent: :destroy
  has_many :grok_calls, as: :grokable, dependent: :destroy

  validates :action_type, inclusion: { in: ACTION_TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :chronological, -> { order(:created_at) }

  def complete?
    status == "complete"
  end

  def failed?
    status == "failed"
  end

  def pending?
    !complete? && !failed?
  end
end
