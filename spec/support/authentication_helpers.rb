# frozen_string_literal: true

# Request-spec helpers for establishing an authenticated session by going
# through the real login endpoint (reCAPTCHA is auto-passed in the test env).
module AuthenticationHelpers
  DEFAULT_PASSWORD = "password123"

  def create_user(username: "alice", password: DEFAULT_PASSWORD)
    User.create!(username: username, password: password, password_confirmation: password)
  end

  def sign_in(user, password: DEFAULT_PASSWORD)
    post login_path, params: { username: user.username, password: password }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
