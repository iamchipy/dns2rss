# frozen_string_literal: true

class SessionsController < ApplicationController
  include Authentication

  before_action :require_no_authentication, only: %i[new]
  before_action :require_authentication, only: %i[destroy]

  def new
    @user = User.new
  end

  def create
    @user = User.find_by(email: params.dig(:user, :email)&.downcase&.strip)

    if @user&.authenticate(params.dig(:user, :password))
      login_user(@user)
      respond_to do |format|
        format.html { redirect_to root_path, notice: "Welcome back!" }
        format.turbo_stream { render turbo_stream: turbo_stream.redirect_to(root_path, notice: "Welcome back!") }
      end
    else
      @user = User.new(email: params.dig(:user, :email))
      flash.now[:alert] = "Invalid email or password"

      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "session_form",
            partial: "sessions/form",
            locals: { user: @user }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    logout_user
    respond_to do |format|
      format.html { redirect_to root_path, notice: "You have been signed out." }
      format.turbo_stream { render turbo_stream: turbo_stream.redirect_to(root_path, notice: "You have been signed out.") }
    end
  end
end