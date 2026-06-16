# frozen_string_literal: true

# Thin seam around the reCAPTCHA gem's (private) controller helper.
#
# Wrapping it here keeps controllers readable and, more importantly, gives the
# verification a single public entry point that can be stubbed in isolation
# during tests without reaching into controller instances.
module CaptchaVerification
  module_function

  def call(controller)
    controller.send(:verify_recaptcha)
  end
end
