class TicketsController < ApplicationController
  require 'http'

  before_action :authenticate_user

  def list
    if params[:id].present?
      event = Event.find_by(id: params[:id].to_i)
      if event.present?
        begin
          token = User.find_by(id: event.user_id).lt_token
          response = HTTP[accept: 'application/json;charset=utf-8'].basic_auth(user: token, pass: '')
                         .get(Rails.application.config.ticketing_base + 'events/' + params[:id])
          render json: JSON.parse(response.body), status: response.status
        rescue
          render json: ErrorResponse.new(code: 404, message: 'LT token of Event creator not found'), adapter: :json, status: :not_found
        end
      else
        render json: ErrorResponse.new(code: 404, message: 'Event not found!'), adapter: :json, status: :not_found
      end
    else
      token = current_user.lt_token
      if token.present?
        response = HTTP[accept: 'application/json;charset=utf-8'].basic_auth(user: token, pass: '')
                       .get(Rails.application.config.ticketing_base + 'events')
        respond response
      else
        render json: ErrorResponse.new, adapter: :json, status: :bad_request
      end
    end
  end

  def get_additional_info
    token = current_user.lt_token
    if token.present? && params[:id].present?
      begin
        response = HTTP[accept: 'application/json;charset=utf-8'].basic_auth(user: token, pass: '')
                       .get(Rails.application.config.ticketing_base + 'events/' + params[:id] + '/additional_info')
        if response.status == 200
          Event.where(id: params[:id].to_i).update(has_registration: true)
        end
        render json: JSON.parse(response.body), status: response.status
      rescue
        render json: ErrorResponse.new, adapter: :json, status: response.status
      end
    else
      render json: ErrorResponse.new, adapter: :json, status: :bad_request
    end
  end

  private

  def respond(response)
    begin
      resp = JSON.parse(response.body)['data']
      # Needs refactoring: Query once against all event ids
      result = []
      resp.each do |i|
        # if i['status'].present? && i['status'].downcase == 'active'
          event = Event.find_by(id: i['remote_id'].to_i)
          if event.present?
            i['theme_url'] = Rails.application.config.resize_cdn_url + event.get_theme
            i['thumb_url'] = Rails.application.config.resize_cdn_url + event.get_theme_thumb
          else
            i['theme_url'] = Rails.application.config.resize_cdn_url + Rails.application.config.default_image
            i['thumb_url'] = Rails.application.config.resize_cdn_url + Rails.application.config.default_image
          end
          result.push(i)
        # end
      end
      if result.present?
        render json: { status: JSON.parse(response.body)['status'], data: result }, status: response.status
      else
        render json: ErrorResponse.new(code: 404, message: 'No Published event found.'), adapter: :json, status: :not_found
      end
    rescue
      render json: ErrorResponse.new, adapter: :json, status: :unprocessable_entity
    end
  end
end
