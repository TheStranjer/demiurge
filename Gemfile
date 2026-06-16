# frozen_string_literal: true

source "https://rubygems.org"

gem "importmap-rails"
gem "jbuilder"
gem "propshaft"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"
gem "rails", "~> 8.1.3"
gem "stimulus-rails"
gem "turbo-rails"

gem "haml-rails"

gem "bcrypt", "~> 3.1.7"

gem "recaptcha", "~> 5.19"

gem "tzinfo-data", platforms: %i[windows jruby]

gem "solid_cable"
gem "solid_cache"
gem "solid_queue"

gem "bootsnap", require: false

gem "kamal", require: false

gem "thruster", require: false

gem "image_processing", "~> 1.2"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  gem "bundler-audit", require: false

  gem "brakeman", require: false

  gem "rubocop", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false

  gem "rspec-rails"
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
