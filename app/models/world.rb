# frozen_string_literal: true

class World < ApplicationRecord
  belongs_to :user
  has_many :characters, dependent: :destroy
  has_many :scenes, dependent: :destroy
  has_many :roll_tables, dependent: :destroy

  validates :title, presence: true, length: { maximum: 255 }
  validates :core_concept, presence: true
end
