class SuperAdminController < ApplicationController

  require 'http'

  before_action :authenticate_super_admin, except: [:login]

  include SuperAdminConcern

  def login # Admin Login
    if params[:email].present? && params[:password].present?
      email = params[:email].downcase

      super_admin = Admin.where(email: /^#{email}$/i).first
      if !super_admin.present? || !super_admin.super_admin
        render json: ErrorResponse.new(code: 404, message: 'Wrong email or password. Try again!'), adapter: :json, status: :not_found and return
      end

      response = HTTP[accept: 'application/json;charset=utf-8']
                     .post(Rails.application.config.ticketing_base+'admins/login', json: {email: super_admin.email, profileID: super_admin.user_id})
      json = JSON.parse(response.body) rescue nil
      if json
        super_admin.lt_token = json['token']
        super_admin.save
      else
        render json: ErrorResponse.new(code: 404, message: 'Wrong email or password. Try again!'), adapter: :json, status: :not_found and return
      end

      user = User.find_by(email: email)
      m = 'Wrong email or password. Try again!'
      if user.present?
        if user.is_facebook_user?
          m = 'Please sign in with Facebook.'
        else
          if !user.isBlocked && user.user_deleted != 1 && user.authenticate(params[:password])
            log_admin_in(user, super_admin)
            return nil
          else
            m = 'Wrong email or password. Try again!'
          end
        end
      end
    else
      m = ''
      m += 'email is required. ' if params[:email].blank?
      m += 'password is required. ' if params[:password].blank?
    end

    render json: ErrorResponse.new(
        code: 401,
        message: 'Invalid Request',
        errors: [
            {message: m}
        ]
    ), adapter: :json, status: :unauthorized

  end


  def ambassador_stats # Stats
    dashboard_stats = get_dashboard_stats

    render json: {stats: dashboard_stats}

  end

  def admins_list # Admin List

    response = HTTP[accept: 'application/json;charset=utf-8'].basic_auth(user: @current_user.lt_token, pass: '').
        get(Rails.application.config.ticketing_base+'admins')

    if response.status.code == 200
      json = JSON.parse(response.body) rescue nil

      data = {admins_list: [], counts: {}}
      if json['data'].present?
        json['data'].each do |item|

          user = User.find_by(email: item['email'])
          if user.present? && user.admin.present?
            item['user_id'] = user.id
            item['username'] = user.username
            item['ambassador_count'] = user.admin.av_users.where(user_status_id: 3).count
            data[:admins_list].push(item)
          end
        end
      end

      #data[:counts] = get_dashboard_stats


      render json: SuccessResponse.new(code: 200, data: data), adapter: :json, status: :ok and return
    else
      render json: ErrorResponse.new(code: 404, message: "No Admins found!"), adapter: :json, status: :not_found and return
    end

  end

  def ambassador_list # Ambassador List

    data = get_ambassador_list(params[:admin_id].present? ? params[:admin_id] : nil)

    if !params[:admin_id].present?
      data[:counts] = get_dashboard_stats
    else
      data[:counts] = []
    end




    render json: SuccessResponse.new(code: 200, data: data), adapter: :json, status: :ok and return

  end

  def account_list # Account List

    data = get_account_list(params[:ambassador_id].present? ? params[:ambassador_id] : nil)

    if !params[:ambassador_id].present?
      data[:counts] = get_dashboard_stats
    else
      data[:counts] = [];
    end


    render json: SuccessResponse.new(code: 200, data: data), adapter: :json, status: :ok and return
  end


end