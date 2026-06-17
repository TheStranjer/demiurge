# frozen_string_literal: true

class EventsController < ApplicationController
  before_action :require_login
  before_action :set_world
  before_action :set_scene

  def create
    return unless narrator_can_act?

    start_player_turn(event_params)
    redirect_to [@world, @scene], notice: t("events.started")
  end

  def narrate
    return unless narrator_can_act?

    prose = narration_params[:prose].to_s.strip
    return redirect_to([@world, @scene], alert: t("events.empty_narration")) if prose.blank?

    @scene.events.create!(prose: prose, status: "complete")
    start_player_turn
    redirect_to [@world, @scene], notice: t("events.narrated")
  end

  def adjudicate
    @event = @scene.events.find(params.expect(:id))
    unless @event.awaiting_gm?
      redirect_to [@world, @scene], alert: t("events.unavailable")
      return
    end

    SceneNarration::GmAdjudication.call(@event, adjudication_tables)
    AdvanceSceneJob.perform_later(@event)
    redirect_to [@world, @scene], notice: t("events.adjudicated")
  rescue ActiveRecord::RecordInvalid
    redirect_to [@world, @scene], alert: t("events.invalid_tables")
  end

  private

  def narrator_can_act?
    return true if narrator_idle?

    redirect_to [@world, @scene], alert: t("events.unavailable")
    false
  end

  def narrator_idle?
    @scene.narrator_mode? && !@scene.finished? && !@scene.awaiting_event? && @scene.awaiting_gm_event.nil?
  end

  def start_player_turn(attributes = {})
    @event = @scene.events.create!(attributes.to_h.merge(status: "pending"))
    AdvanceSceneJob.perform_later(@event)
  end

  def set_world
    @world = current_user.worlds.find(params.expect(:world_id))
  end

  def set_scene
    @scene = @world.scenes.find(params.expect(:scene_id))
  end

  def event_params
    params.expect(event: %i[directive])
  end

  def narration_params
    params.expect(event: %i[prose])
  end

  def adjudication_tables
    raw = params[:tables]
    return [] if raw.blank?

    raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    raw.values
  end
end
