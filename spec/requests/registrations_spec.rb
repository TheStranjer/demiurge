# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "GET /register" do
    it "renders the registration form" do
      get register_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Create an account")
    end

    it "redirects to root when already logged in" do
      sign_in(create_user)
      get register_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /register" do
    let(:valid_params) do
      { user: { username: "newbie", password: "password123", password_confirmation: "password123" } }
    end

    context "with valid data and a passing CAPTCHA" do
      it "creates the user" do
        expect { post register_path, params: valid_params }.to change(User, :count).by(1)
      end

      it "starts a session and redirects to root" do
        post register_path, params: valid_params
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("newbie")
      end
    end

    context "when the CAPTCHA fails" do
      before { allow(CaptchaVerification).to receive(:call).and_return(false) }

      it "does not create a user" do
        expect { post register_path, params: valid_params }.not_to change(User, :count)
      end

      it "re-renders the form with a CAPTCHA error" do
        post register_path, params: valid_params
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("CAPTCHA")
      end
    end

    context "with invalid data" do
      it "does not create a user when the confirmation mismatches" do
        params = valid_params.deep_merge(user: { password_confirmation: "mismatch123" })
        expect { post register_path, params: params }.not_to change(User, :count)
      end

      it "re-renders the form with validation errors" do
        params = valid_params.deep_merge(user: { username: "" })
        post register_path, params: params
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
