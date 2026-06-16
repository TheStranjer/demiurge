# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "renders for a signed-in user" do
      sign_in(create_user(username: "alice"))
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("alice")
    end

    it "redirects guests to the login page" do
      get root_path
      expect(response).to redirect_to(login_path)
    end
  end
end
