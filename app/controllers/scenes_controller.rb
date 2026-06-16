# frozen_string_literal: true

class ScenesController < ApplicationController
  before_action :require_login
  before_action :set_world
  before_action :set_scene, only: %i[show edit update destroy]

  def index
    @scenes = @world.scenes.order(created_at: :desc)
  end

  def show; end

  def new
    @scene = @world.scenes.new
  end

  def edit; end

  def create
    @scene = @world.scenes.new(scene_params)
    @scene.user = current_user

    if @scene.save
      redirect_to [@world, @scene], notice: t("scenes.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @scene.update(scene_params)
      redirect_to [@world, @scene], notice: t("scenes.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @scene.destroy
    redirect_to world_scenes_path(@world), notice: t("scenes.destroyed")
  end

  private

  def set_world
    @world = current_user.worlds.find(params.expect(:world_id))
  end

  def set_scene
    @scene = @world.scenes.find(params.expect(:id))
  end

  def scene_params
    params.expect(scene: %i[premise end_trigger play_mode character_id])
  end
end
