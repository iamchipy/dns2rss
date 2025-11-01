# frozen_string_literal: true

module Ownership
  extend ActiveSupport::Concern

  def authorize_owner!(resource)
    return if resource.owner?(current_user)

    respond_to do |format|
      format.html { redirect_to root_path, alert: "Access denied." }
      format.turbo_stream { head :forbidden }
      format.any { head :forbidden }
    end

    throw :abort
  end

  def authorize_view!(resource)
    return if resource.public? || resource.owner?(current_user)

    respond_to do |format|
      format.html { redirect_to root_path, alert: "Access denied." }
      format.turbo_stream { head :forbidden }
      format.any { head :forbidden }
    end

    throw :abort
  end
end