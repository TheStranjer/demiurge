# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:user) { create_user(username: "alice") }
  let(:credentials) { { username: "alice", password: "password123" } }

  describe "GET /login" do
    it "renders the login form" do
      get login_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sign in")
    end

    it "redirects to root when already logged in" do
      sign_in(user)
      get login_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /login" do
    context "with valid credentials" do
      it "redirects to root" do
        user
        post login_path, params: credentials
        expect(response).to redirect_to(root_path)
      end

      it "creates a session record" do
        user
        expect { post login_path, params: credentials }.to change(Session, :count).by(1)
      end
    end

    context "with an invalid password" do
      it "re-renders the form with an error" do
        user
        post login_path, params: { username: "alice", password: "wrong" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Invalid username or password")
      end
    end

    context "when the CAPTCHA fails" do
      before { allow(CaptchaVerification).to receive(:call).and_return(false) }

      it "re-renders the form without signing in" do
        post login_path, params: credentials
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("CAPTCHA")
      end
    end
  end

  describe "DELETE /logout" do
    it "redirects to the login page" do
      sign_in(user)
      delete logout_path
      expect(response).to redirect_to(login_path)
    end

    it "destroys the session record" do
      sign_in(user)
      expect { delete logout_path }.to change(Session, :count).by(-1)
    end
  end
end
