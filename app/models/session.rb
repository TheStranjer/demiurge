# frozen_string_literal: true

class Session < ApplicationRecord
  DEFAULT_DURATION = 2.weeks

  belongs_to :user

  before_validation :assign_token, on: :create
  before_validation :assign_expiration, on: :create

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(expires_at: Time.current..) }

  def expired?
    expires_at < Time.current
  end

  private

  def assign_token
    self.token ||= SecureRandom.hex(32)
  end

  def assign_expiration
    self.expires_at ||= DEFAULT_DURATION.from_now
  end
end
