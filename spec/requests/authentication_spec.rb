# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authentication apparatus", type: :request do
  let(:user) { create_user(username: "alice") }

  it "keeps a user signed in across requests via the session key" do
    sign_in(user)
    get root_path
    expect(response).to have_http_status(:ok)
  end

  it "logs out and clears a stale key when the session record is gone" do
    sign_in(user)
    user.sessions.destroy_all
    get root_path
    expect(response).to redirect_to(login_path)
  end
end
