class SessionsController < ApplicationController
  require 'http'
  def create
    ambassador = nil
    admin = nil

    if params[:email].present? && params[:password].present?
      email = params[:email].downcase
      email_r = Regexp.new('^' + Regexp.escape(email) + '$', 'i') #case ignored and special charecters escaped
      if request.path.include?("/ambassador/")
        if email.include?("@unation.co")
          admin = Admin.where(email: email_r ).first
          if admin.present?
            response = HTTP[accept: 'application/json;charset=utf-8']
                           .post(Rails.application.config.ticketing_base+'admins/login',  json: {email: admin.email, profileID: admin.user_id})
            json = JSON.parse(response.body) rescue nil
            if json
              admin.lt_token = json['token']
              admin.save
            else
              render json: ErrorResponse.new(code: 404, message: 'Wrong email or password. Try again!'), adapter: :json, status: :not_found and return
            end
          else
            render json: ErrorResponse.new(code: 404, message: 'Wrong email or password. Try again!'), adapter: :json, status: :not_found and return
          end
        else
          if ambassador = AvUser.where(email: email_r ).first
            if ambassador.user_status_id == 1
              render json: ErrorResponse.new(code: 404, message: 'Wrong email or password. Try again!'), adapter: :json, status: :not_found and return
            end
            response = HTTP[accept: 'application/json;charset=utf-8']
                           .post(Rails.application.config.ticketing_base+'ambassadors/login',  json: {email: ambassador.email, profileID: ambassador.user_id })
            json = JSON.parse(response.body) rescue nil
            if json
              ambassador.lt_token = json['token']
              ambassador.save
            else
              render json: ErrorResponse.new(code: 404, message: 'Wrong email or password. Try again!'), adapter: :json, status: :not_found and return
            end
          else
            render json: ErrorResponse.new(code: 404, message: 'Wrong email or password. Try again!'), adapter: :json, status: :not_found and return
          end
        end
      end
      user = User.find_by(email: email) # user email is already down cased
      m = 'Wrong email or password. Try again!'
      if user.present?
        if user.is_facebook_user?
          m = 'Please sign in with Facebook.'
        else
          if user.type != 2 && !user.isBlocked && user.user_deleted != 1 && user.authenticate(params[:password])
           log_user_in(user, ambassador, admin)
            return nil
          else
            user.update!(login_attempts: user.login_attempts.to_i + 1, isBlocked:  user.login_attempts > Rails.application.config.max_login_attempts) if user.type != 2
            m = 'Wrong email or password. Try again!'
            m = 'One more try before your account is locked!' if user.isLastAttempt
            m = 'Your account is locked. Tap Forgot Password below.' if user.isBlocked
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
      ],
      isLastAttempt: (user.present?) ? user.isLastAttempt : false,
      isBlocked: (user.present?) ? user.isBlocked : false
    ), adapter: :json, status: :unauthorized
  end

  def create_facebook
    facebook_response = HTTP.get(Rails.application.config.fb_session_create_base + params['facebooktoken'])
    body = JSON.parse(facebook_response.body.as_json[0])
    email_facebook = body['email']
    fb_id = body['id']
    if fb_id.present? && email_facebook.present?
      user = User.or( {fb_id: fb_id} , {email: email_facebook} ).first
      if user.present? && user.type != 2 && user.fb_id.present?
        av_user = nil
        if request.path.include?("/ambassador/")
          if av_user = AvUser.find_by(email: email_facebook)
            log_user_in(user, av_user)
            return nil
          else
            render json: { data: ErrorResponse.new(code: 401, message: 'unauthorized user') }, adapter: :json, status: :not_found and return
          end
        else
          log_user_in(user, av_user)
          return nil
        end
      else
        render json: ErrorResponse.new(
                   code: 404,
                   message: 'Invalid Request',
                   errors: [
                       {message: 'Authentication failed. Facebook user not registered.'}
                   ],
                   isLastAttempt: (user.present?) ? user.isLastAttempt : false,
                   isBlocked: (user.present?) ? user.isBlocked : false
               ), adapter: :json, status: :unauthorized and return
      end
    else
      render json: ErrorResponse.new(
                 code: 404,
                 message: 'Invalid Request',
                 errors: [
                     {message: 'Authentication failed. Facebook user not registered.'}
                 ],
                 isLastAttempt: (user.present?) ? user.isLastAttempt : false,
                 isBlocked: (user.present?) ? user.isBlocked : false
             ), adapter: :json, status: :unauthorized
    end
  end

  private
    def log_user_in(user, av_user = nil, admin = nil)
      isAmbassador =  av_user
      token = user.generate_token
      user.update_attribute( :login_attempts, 0)
      user.update_attribute( :last_login_at, Time.now)
      if av_user.present? || admin.present?
        render json: { data: Session.new(
          code:             200,
          token:            token.access_token,
          username:         user.username,
          profileId:        user.id,
          avatarUrl:        Rails.application.config.resize_cdn_url + user.get_avatar,
          isBrand:          user.isBrand,
          type:             user.type,
          userId:           user.id,
          radius:           user.radius,
          avUserId:         (isAmbassador)? av_user.id : nil,
          isAmbassador:     isAmbassador.present? ? true : false,
          hasStripeAccount: (isAmbassador)? av_user.has_stripe_linked : false,
          email:            (isAmbassador)? av_user.email : user.email,
          status:           (isAmbassador)? av_user.user_status_id : nil,
          fname:            (isAmbassador)? av_user.fname : nil,
          lname:            (isAmbassador)? av_user.lname : nil,
          isNewAmbassador:  (isAmbassador)? av_user.is_new : nil,
          showContract:     (isAmbassador)? av_user.showContract[:permission] : nil,
          contractPosition: (isAmbassador)? av_user.showContract[:position] : nil
      ), adapter: :json, status: :ok }
      else
        render json: Session.new(
        code:             200,
        token:            token.access_token,
        username:         user.username,
        profileID:        user.id,
        avatarUrl:        Rails.application.config.resize_cdn_url + user.get_avatar,
        isBrand:          user.isBrand,
        type:             user.type,
        userId:           user.id,
        radius:           user.radius,
        avUserId:         (isAmbassador)? av_user.id : nil,
        isAmbassador:     isAmbassador.present? ? true : false,
        hasStripeAccount: (isAmbassador)? av_user.has_stripe_linked : false,
        email:            (isAmbassador)? av_user.email : user.email
      ), adapter: :json, status: :ok
      end
    end

    def log_in_lt(ambassador)
      if ambassador.present?
        response = HTTP[accept: 'application/json;charset=utf-8']
                       .post(Rails.application.config.ticketing_base+'ambassadors/login',  json: {email: ambassador.email, profileID: ambassador.user_id})
        if response.present? && (response.status == 200 || response.status == 'OK')
          true
        else
          false
        end
      else
        false
      end
    end

end
