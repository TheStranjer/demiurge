# frozen_string_literal: true

class CharactersController < ApplicationController
  before_action :require_login
  before_action :set_world
  before_action :set_character, only: %i[show edit update destroy]

  def index
    @characters = @world.characters.order(:name)
  end

  def show; end

  def new
    @character = @world.characters.new
  end

  def edit; end

  def create
    @character = @world.characters.new(character_params)

    if @character.save
      redirect_to [@world, @character], notice: t("characters.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @character.update(character_params)
      redirect_to [@world, @character], notice: t("characters.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @character.destroy
    redirect_to world_characters_path(@world), notice: t("characters.destroyed")
  end

  private

  def set_world
    @world = current_user.worlds.find(params.expect(:world_id))
  end

  def set_character
    @character = @world.characters.find(params.expect(:id))
  end

  def character_params
    params.expect(character: [:name, :sex, :non_player_character, *Character::STATS])
  end
end
