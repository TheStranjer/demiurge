# frozen_string_literal: true

class AdvanceSceneJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 8
  INTENT_STATUSES = %w[pending declaring].freeze
  TERMINAL_OUTCOMES = %i[complete awaiting_gm].freeze

  def perform(event)
    return if event.complete? || event.awaiting_gm?

    event.update!(attempts: event.attempts + 1)
    outcome = advance(event)
    reschedule(event) unless TERMINAL_OUTCOMES.include?(outcome)
  rescue StandardError
    reschedule(event)
    raise
  end

  private

  def advance(event)
    if INTENT_STATUSES.include?(event.status)
      SceneNarration::IntentDeclarer.call(event)
    else
      SceneNarrator.call(event)
    end
  end

  def reschedule(event)
    if event.attempts >= MAX_ATTEMPTS
      event.update!(status: "failed")
    else
      self.class.set(wait: backoff(event)).perform_later(event)
    end
  end

  def backoff(event)
    (2**event.attempts).seconds
  end
end
