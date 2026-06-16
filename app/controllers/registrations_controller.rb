# frozen_string_literal: true

class RegistrationsController < ApplicationController
  before_action :require_logged_out

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    return deny_captcha unless CaptchaVerification.call(self)

    if @user.save
      start_session_for(@user)
      redirect_to root_path, notice: t("registrations.welcome", username: @user.username)
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def deny_captcha
    @user.errors.add(:base, t("registrations.captcha_failed"))
    render :new, status: :unprocessable_content
  end

  def user_params
    params.expect(user: %i[username password password_confirmation])
  end
end
