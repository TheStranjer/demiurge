# frozen_string_literal: true

# Provide dummy reCAPTCHA keys so `recaptcha_tags` can render in views during
# tests. Verification itself is short-circuited to true by the gem in the test
# environment (Recaptcha::Configuration#skip_verify_env), so these are never
# sent anywhere.
Recaptcha.configure do |config|
  config.site_key = "test-site-key"
  config.secret_key = "test-secret-key"
end
