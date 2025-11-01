# frozen_string_literal: true

module AuthenticationHelper
  def current_user
    @current_user ||= session_user
  end

  def logged_in?
    current_user.present?
  end

  private

  def session_user
    return unless session[:user_id]

    User.find_by(id: session[:user_id])
  end
end