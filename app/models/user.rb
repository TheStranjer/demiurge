# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy

  normalizes :username, with: ->(value) { value.to_s.strip.downcase }

  validates :username,
            presence: true,
            uniqueness: true,
            length: { minimum: 3, maximum: 30 },
            format: { with: /\A[a-z0-9_]+\z/, message: :invalid_characters }
  validates :password, length: { minimum: 8 }, allow_nil: true
end
