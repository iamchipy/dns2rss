class ApplicationController < ActionController::Base
  include Authentication

  before_action :assign_current_user

  private

  def assign_current_user
    Current.user = current_user
  end
end
