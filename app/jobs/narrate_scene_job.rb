# frozen_string_literal: true

class NarrateSceneJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 8

  def perform(event)
    return if event.complete?

    event.update!(attempts: event.attempts + 1)
    outcome = SceneNarrator.call(event)
    reschedule(event) unless outcome == :complete
  rescue StandardError
    reschedule(event)
    raise
  end

  private

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
