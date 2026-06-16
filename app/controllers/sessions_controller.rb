# frozen_string_literal: true

class SessionsController < ApplicationController
  before_action :require_logged_out, only: %i[new create]

  def new; end

  def create
    return deny_captcha unless CaptchaVerification.call(self)

    user = User.authenticate_by(username: params[:username], password: params[:password])
    if user
      start_session_for(user)
      redirect_to root_path, notice: t("sessions.signed_in")
    else
      flash.now[:alert] = t("sessions.invalid_credentials")
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    reset_current_session
    redirect_to login_path, notice: t("sessions.signed_out")
  end

  private

  def deny_captcha
    flash.now[:alert] = t("sessions.captcha_failed")
    render :new, status: :unprocessable_content
  end
end
