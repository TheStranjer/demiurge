# frozen_string_literal: true

# reCAPTCHA v2 ("I'm not a robot" checkbox) configuration.
#
# The keys are read from the environment so they never live in source control.
# In the test environment the gem short-circuits +verify_recaptcha+ to true
# (see Recaptcha::Configuration#skip_verify_env), so no real keys are required.
Recaptcha.configure do |config|
  config.site_key = ENV.fetch("RECAPTCHA_SITE_KEY", nil)
  config.secret_key = ENV.fetch("RECAPTCHA_SECRET_KEY", nil)
end
