# frozen_string_literal: true

class UsersController < ApplicationController
  include Authentication

  before_action :require_no_authentication, only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      login_user(@user)
      respond_to do |format|
        format.html { redirect_to root_path, notice: "Welcome! Your account has been created." }
        format.turbo_stream { render turbo_stream: turbo_stream.redirect_to(root_path, notice: "Welcome! Your account has been created.") }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "user_form",
            partial: "users/form",
            locals: { user: @user }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end