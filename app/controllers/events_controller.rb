# frozen_string_literal: true

class EventsController < ApplicationController
  before_action :require_login
  before_action :set_world
  before_action :set_scene

  def create
    unless @scene.narrator_mode? && !@scene.finished?
      redirect_to [@world, @scene], alert: t("events.unavailable")
      return
    end

    @event = @scene.events.create!(event_params.merge(status: "pending"))
    NarrateSceneJob.perform_later(@event)
    redirect_to [@world, @scene], notice: t("events.started")
  end

  private

  def set_world
    @world = current_user.worlds.find(params.expect(:world_id))
  end

  def set_scene
    @scene = @world.scenes.find(params.expect(:scene_id))
  end

  def event_params
    params.expect(event: %i[action_type directive])
  end
end
