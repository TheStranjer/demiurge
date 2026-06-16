# frozen_string_literal: true

class GrokCall < ApplicationRecord
  belongs_to :grokable, polymorphic: true

  validates :payload, presence: true
end
