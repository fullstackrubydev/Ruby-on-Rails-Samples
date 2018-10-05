class SocialMediaController < ApplicationController
  require 'oauth'
  require 'twitter'
  # require 'linkedin'
  require 'linkedin-oauth2'

  before_action :authenticate_user

  def get_twitter_auth
    consumer = get_twitter_consumer
    callback_url = Rails.application.config.twitter_callback_url
    # Todo: set in congfig
    request_token = consumer.get_request_token(:oauth_callback => callback_url)
    if request_token.present? && request_token.token.present?
      social_token = TokenSocial.where(user: current_user, type: 1).first
      if social_token.present?
        social_token.update!(token: request_token.token, secret: request_token.secret)
      else
        TokenSocial.create!(user: current_user, type: 1, token: request_token.token, secret: request_token.secret)
      end
      render json: SuccessResponse.new(data:{message: '', url: request_token.authorize_url}),
             adapter: :json, status: :ok
    else
      render json: ErrorResponse.new(code: 401, message: 'Unauthorized Access'), adapter: :json, status: :unauthorized
    end
  end

  def get_twitter_access
    social_token = TokenSocial.where(user_id: current_user.id, type: 1, token: params[:oauth_token]).first
    if params[:oauth_token].present? && params[:oauth_verifier].present? && social_token.present? && social_token.token == params[:oauth_token]
      consumer = get_twitter_consumer
      request_token = OAuth::RequestToken.new(consumer, social_token.token, social_token.secret)
      access_token = request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])
      if access_token.present?
        # update with access token
        social_token.update!(token: access_token.token, secret: access_token.secret, authenticated: true)
        render json: SuccessResponse.new(data:{message: 'Access token has been fetched.', status: 'Success'}),
               adapter: :json, status: :ok
      else
        render json: ErrorResponse.new(code: 401, message: 'Twitter Access Token not fetched.'), adapter: :json, status: :unauthorized
      end
    else
      render json: ErrorResponse.new(code: 401, message: 'Unauthorized Access'), adapter: :json, status: :unauthorized
    end
  end

  def share_event_twitter
    social_token = TokenSocial.where(user_id: current_user.id, type: 1).first
    if social_token.present?
      client = Twitter::REST::Client.new(
          :consumer_key => Rails.application.secrets.twitter_api_key,
          :consumer_secret => Rails.application.secrets.twitter_api_secret,
          :access_token => social_token.token,
          :access_token_secret => social_token.secret
      )
      twitter_user = client.user
      if twitter_user.present?
        event = Event.find_by(id: params[:eventid].to_i)
        # Make a URL to post to twitter (below) that directs to a template for this event (if the rewrite engine detects a crawler bot)
        event_share_url = "#{Rails.application.config.event_share_base + SecureRandom.hex(16).to_s + '/' + event.id.to_s}"
        client.update(event_share_url)
      else
        render json: ErrorResponse.new(code: 401, message: 'Twitter User not found.'), adapter: :json, status: :unauthorized
      end
    else
      render json: ErrorResponse.new(code: 401, message: 'Unauthorized Access'), adapter: :json, status: :unauthorized
    end
  end

  def get_linkedin_auth
    social_token = TokenSocial.where(user: current_user, type: 2).first
    if social_token.present? && social_token.token.present?
      render json: SuccessResponse.new(data: { message: '', url: '',  isAssociated: true }),
             adapter: :json, status: :ok
    else
      consumer = LinkedIn::OAuth2.new
      # Todo: set in congfig
      request_token = consumer.auth_code_url
      if request_token.present?
        if social_token.blank?
          TokenSocial.create!(user: current_user, type: 2)
        end
        authorize_url = "#{request_token}"
        render json: SuccessResponse.new(data:{message: '', url: authorize_url, isAssociated: false}),
               adapter: :json, status: :ok
      else
        render json: ErrorResponse.new(code: 401, message: 'Unauthorized Access'), adapter: :json, status: :unauthorized
      end
    end
  end

  def get_linkedin_access
    social_token = TokenSocial.where(user_id: current_user.id, type: 2).first
    if params[:code].present? && social_token.present?
      consumer = LinkedIn::OAuth2.new
      request_token = consumer.get_access_token(params[:code])
      access_token = request_token.token
      unless access_token.blank?
        # update with access token
        social_token.update!(token: access_token, authenticated: true)
        render json: SuccessResponse.new(data:{message: 'Access token has been fetched.', status: 'Success'}),
               adapter: :json, status: :ok
      else
        render json: ErrorResponse.new(code: 401, message: 'Linkedin Access Token not fetched.'), adapter: :json, status: :unauthorized
      end
    else
      render json: ErrorResponse.new(code: 401, message: 'Unauthorized Access'), adapter: :json, status: :unauthorized
    end
  end

  def share_event_linkedin
    social_token = TokenSocial.where(user_id: current_user.id, type: 2).first
    if social_token.present? && social_token.token.present?
      linkedin_user = LinkedIn::API.new(social_token.token)
      if linkedin_user.present?
        event = Event.find_by(id: params[:eventid].to_i)
        # Make a URL to post to linkedin (below) that directs to a template for this event (if the rewrite engine detects a crawler bot)
        event_share_url = "#{Rails.application.config.event_share_base + SecureRandom.hex(16).to_s + '/' + event.id.to_s}"
        linkedin_user.add_share(comment: event_share_url )
      else
        render json: ErrorResponse.new(code: 401, message: 'Linkedin User not found.'), adapter: :json, status: :unauthorized
      end
    else
      render json: ErrorResponse.new(code: 401, message: 'Unauthorized Access'), adapter: :json, status: :unauthorized
    end
  end

  private

  def get_twitter_consumer
    OAuth::Consumer.new(Rails.application.secrets.twitter_api_key, Rails.application.secrets.twitter_api_secret, :site => 'https://twitter.com')
  end
end
