# frozen_string_literal: true

class WorldsController < ApplicationController
  before_action :require_login
  before_action :set_world, only: %i[show edit update destroy]

  def index
    @worlds = current_user.worlds.order(created_at: :desc)
  end

  def show; end

  def new
    @world = current_user.worlds.new
  end

  def edit; end

  def create
    @world = current_user.worlds.new(world_params)

    if @world.save
      redirect_to @world, notice: t("worlds.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @world.update(world_params)
      redirect_to @world, notice: t("worlds.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @world.destroy
    redirect_to worlds_path, notice: t("worlds.destroyed")
  end

  private

  def set_world
    @world = current_user.worlds.find(params.expect(:id))
  end

  def world_params
    params.expect(world: %i[title core_concept])
  end
end
