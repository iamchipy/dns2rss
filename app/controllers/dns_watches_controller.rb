# frozen_string_literal: true

class DnsWatchesController < ApplicationController
  include Ownership

  before_action :require_authentication, only: %i[create update destroy]
  before_action :set_dns_watch, only: %i[show update destroy]
  before_action :authorize_view!, only: :show
  before_action :authorize_owner!, only: %i[update destroy]

  def index
    @dns_watch_form = build_form_watch
    @dns_watches = collection_scope
  end

  def show
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "dns_watch_details",
          partial: "dns_watches/details",
          locals: { dns_watch: @dns_watch }
        )
      end
      format.html
    end
  end

  def create
    @dns_watch = current_user.dns_watches.build(dns_watch_params)

    if @dns_watch.save
      @dns_watch_form = build_form_watch
      @dns_watches = collection_scope

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to dns_watches_path, notice: "DNS watch created." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "dns_watch_form",
            partial: "dns_watches/form",
            locals: { dns_watch: @dns_watch }
          ), status: :unprocessable_entity
        end
        format.html do
          @dns_watch_form = @dns_watch
          @dns_watches = collection_scope
          render :index, status: :unprocessable_entity
        end
      end
    end
  end

  def update
    if @dns_watch.update(dns_watch_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to dns_watches_path, notice: "DNS watch updated." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            @dns_watch,
            partial: "dns_watches/dns_watch",
            locals: { dns_watch: @dns_watch }
          ), status: :unprocessable_entity
        end
        format.html do
          @dns_watch_form = build_form_watch
          @dns_watches = collection_scope
          render :index, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    @dns_watch.destroy
    @dns_watches = collection_scope

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to dns_watches_path, notice: "DNS watch removed." }
    end
  end

  private

  def collection_scope
    DnsWatch.includes(:user).visible_to(current_user).order(:domain, :record_type, :record_name, :id)
  end

  def dns_watch_params
    params.require(:dns_watch).permit(:domain, :record_type, :record_name, :check_interval_minutes, :visibility)
  end

  def set_dns_watch
    @dns_watch = DnsWatch.find(params[:id])
  end

  def authorize_view!
    return if @dns_watch.public? || @dns_watch.owner?(current_user)

    raise ActiveRecord::RecordNotFound
  end

  def authorize_owner!
    return if @dns_watch.owner?(current_user)

    raise ActiveRecord::RecordNotFound
  end

  def build_form_watch
    if current_user.present?
      current_user.dns_watches.build(visibility: DnsWatch.visibilities[:private])
    else
      DnsWatch.new
    end
  end
end
