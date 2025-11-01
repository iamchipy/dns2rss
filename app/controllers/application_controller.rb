class ApplicationController < ActionController::Base
  before_action :assign_current_user

  helper_method :current_user

  private

  def assign_current_user
    Current.user = session_user
  end

  def session_user
    return unless session[:user_id]

    User.find_by(id: session[:user_id])
  end

  def current_user
    Current.user
  end

  def require_authenticated_user
    return if current_user.present?

    respond_to do |format|
      format.html do
        redirect_to root_path, alert: "You must sign in to manage watches."
      end
      format.turbo_stream { head :unauthorized }
      format.any { head :unauthorized }
    end

    throw :abort
  end
end
