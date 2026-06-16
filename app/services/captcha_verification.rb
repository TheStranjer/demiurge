# frozen_string_literal: true

module CaptchaVerification
  module_function

  def call(controller)
    controller.send(:verify_recaptcha)
  end
end
