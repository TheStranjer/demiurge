# frozen_string_literal: true

class HomeController < ApplicationController
  before_action :require_login

  def index; end
end
