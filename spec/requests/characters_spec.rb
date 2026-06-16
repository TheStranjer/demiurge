# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Characters", type: :request do
  let(:user) { create_user(username: "alice") }
  let(:world) { user.worlds.create!(title: "Aerth", core_concept: "A world of floating islands.") }
  let(:valid_attributes) do
    {
      name: "Kara",
      sex: "female",
      non_player_character: false,
      strength: 1, dexterity: 2, endurance: 3,
      intelligence: 0, awareness: -1, willpower: 5,
      charisma: -5, finesse: 4, tact: -2,
    }
  end
  let(:valid_params) { { character: valid_attributes } }

  def create_character(target_world = world, name: "Kara")
    target_world.characters.create!(valid_attributes.merge(name: name))
  end

  describe "when logged out" do
    it "redirects index to the login page" do
      get world_characters_path(world)
      expect(response).to redirect_to(login_path)
    end

    it "does not create a character" do
      expect { post world_characters_path(world), params: valid_params }.not_to change(Character, :count)
      expect(response).to redirect_to(login_path)
    end
  end

  describe "when logged in" do
    before { sign_in(user) }

    it "lists the world's characters" do
      create_character(name: "Kara")
      get world_characters_path(world)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Kara")
    end

    it "renders the new form" do
      get new_world_character_path(world)
      expect(response).to have_http_status(:ok)
    end

    it "renders the edit form" do
      character = create_character
      get edit_world_character_path(world, character)
      expect(response).to have_http_status(:ok)
    end

    it "creates a character belonging to the world" do
      expect { post world_characters_path(world), params: valid_params }.to change(world.characters, :count).by(1)
      expect(response).to redirect_to(world_character_path(world, Character.last))
    end

    it "rejects an invalid character" do
      expect do
        post world_characters_path(world), params: { character: valid_attributes.merge(name: "") }
      end.not_to change(Character, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "shows a character" do
      character = create_character
      get world_character_path(world, character)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Kara")
    end

    it "updates a character" do
      character = create_character
      patch world_character_path(world, character), params: { character: { name: "Kara Reborn" } }
      expect(response).to redirect_to(world_character_path(world, character))
      expect(character.reload.name).to eq("Kara Reborn")
    end

    it "rejects an invalid update" do
      character = create_character
      patch world_character_path(world, character), params: { character: { strength: 99 } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(character.reload.strength).to eq(1)
    end

    it "destroys a character" do
      character = create_character
      expect { delete world_character_path(world, character) }.to change(Character, :count).by(-1)
      expect(response).to redirect_to(world_characters_path(world))
    end
  end

  describe "another user's world" do
    let(:other_world) do
      create_user(username: "bob").worlds.create!(title: "Secret", core_concept: "Hidden.")
    end

    before { sign_in(user) }

    it "does not list its characters" do
      get world_characters_path(other_world)
      expect(response).to have_http_status(:not_found)
    end

    it "does not show its characters" do
      character = create_character(other_world)
      get world_character_path(other_world, character)
      expect(response).to have_http_status(:not_found)
    end

    it "does not create a character in it" do
      expect { post world_characters_path(other_world), params: valid_params }.not_to change(Character, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "does not destroy its characters" do
      character = create_character(other_world)
      expect { delete world_character_path(other_world, character) }.not_to change(Character, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
