# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :logged_in?
  end

  def current_user
    @current_user ||= session_user
  end

  def logged_in?
    current_user.present?
  end

  def require_authentication
    return if logged_in?

    respond_to do |format|
      format.html { redirect_to login_path, alert: "Please sign in to continue." }
      format.turbo_stream { head :unauthorized }
      format.any { head :unauthorized }
    end

    throw :abort
  end

  def require_no_authentication
    return unless logged_in?

    respond_to do |format|
      format.html { redirect_to root_path, notice: "You are already signed in." }
      format.turbo_stream { head :found }
      format.any { head :found }
    end

    throw :abort
  end

  private

  def session_user
    return unless session[:user_id]

    User.find_by(id: session[:user_id])
  end

  def login_user(user)
    session[:user_id] = user.id
    @current_user = user
  end

  def logout_user
    session.delete(:user_id)
    @current_user = nil
  end
end