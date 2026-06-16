# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Worlds", type: :request do
  let(:user) { create_user(username: "alice") }
  let(:valid_params) { { world: { title: "Aerth", core_concept: "A world of floating islands." } } }

  describe "when logged out" do
    it "redirects index to the login page" do
      get worlds_path
      expect(response).to redirect_to(login_path)
    end

    it "does not create a world" do
      expect { post worlds_path, params: valid_params }.not_to change(World, :count)
      expect(response).to redirect_to(login_path)
    end
  end

  describe "when logged in" do
    before { sign_in(user) }

    it "lists the current user's worlds" do
      user.worlds.create!(title: "Aerth", core_concept: "Floating islands.")
      get worlds_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Aerth")
    end

    it "creates a world belonging to the current user" do
      expect { post worlds_path, params: valid_params }.to change(user.worlds, :count).by(1)
      expect(response).to redirect_to(world_path(World.last))
    end

    it "rejects an invalid world" do
      expect do
        post worlds_path, params: { world: { title: "", core_concept: "" } }
      end.not_to change(World, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "shows a world" do
      world = user.worlds.create!(title: "Aerth", core_concept: "Floating islands.")
      get world_path(world)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Floating islands.")
    end

    it "updates a world" do
      world = user.worlds.create!(title: "Aerth", core_concept: "Floating islands.")
      patch world_path(world), params: { world: { title: "Aerth Reborn" } }
      expect(response).to redirect_to(world_path(world))
      expect(world.reload.title).to eq("Aerth Reborn")
    end

    it "destroys a world" do
      world = user.worlds.create!(title: "Aerth", core_concept: "Floating islands.")
      expect { delete world_path(world) }.to change(World, :count).by(-1)
      expect(response).to redirect_to(worlds_path)
    end

    it "does not expose another user's worlds" do
      other = create_user(username: "bob")
      world = other.worlds.create!(title: "Secret", core_concept: "Hidden.")
      get world_path(world)
      expect(response).to have_http_status(:not_found)
    end
  end
end
