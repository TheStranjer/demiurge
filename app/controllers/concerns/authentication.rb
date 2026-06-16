# frozen_string_literal: true

# Session-key based authentication apparatus.
#
# A logged-in user is tracked solely through a +session_key+ stored in the
# encrypted Rails +session+ cookie. The key is the random hex token of a
# +Session+ record; everything else (the user, login state) is derived from it.
module Authentication
  extend ActiveSupport::Concern

  SESSION_KEY = :session_key

  included do
    helper_method :current_user, :logged_in?
  end

  private

  def current_session
    return @current_session if defined?(@current_session)

    @current_session = resolve_session
  end

  def resolve_session
    key = session[SESSION_KEY]
    return if key.blank?

    record = Session.active.find_by(token: key)
    session.delete(SESSION_KEY) if record.nil?
    record
  end

  def current_user
    current_session&.user
  end

  def logged_in?
    current_user.present?
  end

  def start_session_for(user)
    @current_session = user.sessions.create!
    session[SESSION_KEY] = @current_session.token
  end

  def reset_current_session
    current_session&.destroy
    reset_session
  end

  def require_login
    return if logged_in?

    redirect_to login_path, alert: t("authentication.require_login")
  end

  def require_logged_out
    return unless logged_in?

    redirect_to root_path, notice: t("authentication.already_logged_in")
  end
end
