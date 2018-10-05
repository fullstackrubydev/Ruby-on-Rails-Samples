class AvUsersController < ApplicationController
  require 'http'

  require 'send_av_invitation_worker'
  require 'send_account_invitation_worker'
  require 'send_account_invitation_by_mail_worker'
  require 'send_account_invitation_accepted_worker'
  require 'send_account_confirmation_worker'
  require 'send_av_accepted_invite_worker'

  before_action :sanitize_params
  before_action :authenticate_user, except: [ :associate_av, :associate_account ]

  include AvUsersConcern

  #region Actions

  def associate_account
    if params[:token].present?
      token = AssociationToken.find_by(invitation_token: params[:token])
      if token.present?
        if token.account_id.present?
          account = Account.find(token.account_id)
          if user = User.find_by(email: account.email)
            account_user_id = nil
            if token.email.present?
              Account.where(email: token.email).update_all(user_status_id: 6)
              account_user_id = user.id
            else
              account_user_id = account.user_id
            end
            user = User.find(account_user_id.to_i)
            user.accounts.update_all(user_status_id: 6)
            if user.av_user.present?
              ambassador = user.av_user
              ambassador.update_attribute(:user_status_id, 6)
            end
            if account = Account.find(token.account_id)
              account.user_status_id = 5
              account.av_user_id = token.av_user_id
              account.inv_acception_date = Time.now
              account.invitation_expiry_date = Time.now + 12.months
              account.user_id = account_user_id
              account.save!
              create_lt_account(account.av_user, account.user, account)
              # AvMailer.account_accepted_invite(account).deliver_now
              SendAccountInvitationAcceptedWorker.perform_async(account.id)
              SendAccountConfirmationWorker.perform_async(account.id)
              render json: { data: SuccessResponse.new(
                         code: 200, isRegistered: true, message: 'Account associated with the AV successfully.',

                     )}, adapter: :json, status: :ok
            else
              render json: { data: ErrorResponse.new(
                         code: 400, message: 'This account is associated with another AV.'

                     ) }, adapter: :json, status: :bad_request
            end
          else
            render json: { data: SuccessResponse.new(
                       code: 200, isRegistered: false, message: 'successfully.',

                   )}, adapter: :json, status: :ok
          end
        else
          account = Account.find_by(email: token.email, av_user_id: token.av_user_id.to_i)
          account.user_status_id = 1
          account.av_user_id = token.av_user_id
          account.inv_acception_date = Time.now
          account.invitation_expiry_date = Time.now + 12.months
          if account.save!
            token.account_id = account.id
            token.save!
            render json: { data: SuccessResponse.new(
                       code: 200, isRegistered: false, message: 'successfully.',

                   )}, adapter: :json, status: :ok
          else
            render json: { data: ErrorResponse.new(
                       code: 400, message: 'This account is associated with another AV.'

                   ) }, adapter: :json, status: :bad_request
          end
        end
      else
        render json: { data: ErrorResponse.new(
                   code: 400, message: 'Token is Expired.'

               ) }, adapter: :json, status: :bad_request
      end
    else
      render json: { data: ErrorResponse.new(
                 code: 400, message: 'Token is required.'

             ) }, adapter: :json, status: :bad_request
    end
  end

  #Get Accounts List
  def list_accounts
    if params[:avuserid].present?
      if ambassador = AvUser.find(params[:avuserid].to_i)
        accounts = ambassador.accounts
        if accounts.count > 0
          json = get_av_accounts_from_lt(ambassador)
          json['data'].each do | record |
            if account = accounts.find_by(email: record['email'])
              account.total_events = record['ticketed_events']
              account.total_revenue = record['total_revenue']
              account.save
            end
          end
          accounts = ambassador.accounts
          data =  ActiveModel::Serializer::CollectionSerializer.new(accounts, each_serializer: AccountSerializer)
          render json: { data: data  }, status: :ok
        else
          render json: { data: ErrorResponse.new(code: 404, message: 'This ambassador/venue has no associated account.') }, adapter: :json, status: :not_found
        end
      else
        render json: { data: ErrorResponse.new(code: 404, message: 'This ambassador/venue is not found.') }, adapter: :json, status: :not_found
      end
    else
      render json: { data: ErrorResponse.new(code: 400, message: 'AVUserID is required') }, adapter: :json, status: :not_found
    end
  end

  #List Ambassadors
  def index
    ambassadors = current_user.av_users
    if current_user.av_users.size > 0
      json = get_list_from_lt(current_user)
      json['data'].each do | record |
        if ambassador = ambassadors.find_by(email: record['email'])
          ambassador.total_accounts = ambassador.accounts.where(user_status_id: 5).count
          ambassador.total_earned = record['total_earned']
          ambassador.save
        end
      end

      ambassadors = current_user.av_users
      data =  ActiveModel::Serializer::CollectionSerializer.new(ambassadors, each_serializer: AvUserSerializer)
      render json: { data:  data }, status: :ok
    else
      render json: {data: ErrorResponse.new(code: 404, message: 'Ambassadors not found!') }, adapter: :json, status: :not_found
    end
  end

  #Get AV User details for invitation
  def invitation_details
    if user = User.find_by(email: params[:email])
      if user.type == 2
        render json: { data: ErrorResponse.new(code: 404, message: 'This ambassador/venue is not found.') }, adapter: :json, status: :not_found
      elsif user.av_user.present? || user.accounts.present? && (user.accounts.pluck(:user_status_id) & [5, 6]).any?
        render json: { data: ErrorResponse.new(code: 401, message: 'This ambassador/venue is associated with another admin.') }, adapter: :json, status: :not_found
      else
        render json: { data:  UserInviteSerializer.new(user) }, status: :ok
      end
    else
      render json: { data: ErrorResponse.new(code: 404, message: 'This ambassador/venue is not found.') }, adapter: :json, status: :not_found
    end
  end

  def validate_account
    if params[:resendinviteaccount].blank?
      if user = User.find_by(email: params[:accountemail])
        if user.av_user.present? && user.av_user.user_status_id != 1
          render json: { data: ErrorResponse.new(code: 401, message: 'Invitation cannot be sent to this user.') }, adapter: :json, status: :not_found
        elsif user.accounts.present?  && (user.accounts.pluck(:user_status_id) & [5, 6]).any?
          render json: { data: ErrorResponse.new(code: 401, message: 'This account is associated with another ambassador/venue.') }, adapter: :json, status: :not_found
        elsif user.accounts.present? && (user.accounts.pluck(:av_user_id).include? current_user.id)
          render json: { data: ErrorResponse.new(code: 401, message: 'This account has already been invited.') }, adapter: :json, status: :not_found
        else
          render json: { data: SuccessResponse.new(code: 200, message: 'Successful') }, adapter: :json, status: :ok
        end
      else
        account = Account.find_by(email: params[:accountemail], av_user_id: current_user.id)
        if (Account.where(email: params[:accountemail]).pluck(:user_status_id) & [5, 6]).any?
          render json: { data: ErrorResponse.new(code: 401, message: 'This account is associated with another ambassador/venue.') }, adapter: :json, status: :not_found
        elsif account.present?
          render json: { data: ErrorResponse.new(code: 401, message: 'This account has already been invited.') }, adapter: :json, status: :not_found
        else
          render json: { data: SuccessResponse.new(code: 200, message: 'Successful') }, adapter: :json, status: :ok
        end
      end
    else
      if user = User.find_by(email: params[:resendinviteaccount])
        if user.av_user.present? && user.av_user.user_status_id != 1
          render json: { data: ErrorResponse.new(code: 401, message: 'Invitation cannot be sent to this user.') }, adapter: :json, status: :not_found
        elsif user.accounts.present?  && (user.accounts.pluck(:user_status_id) & [5, 6]).any?
          render json: { data: ErrorResponse.new(code: 401, message: 'This account is associated with another ambassador/venue.') }, adapter: :json, status: :not_found
        elsif user.accounts.present? && (user.accounts.pluck(:av_user_id).include? current_user.id)
          render json: { data: ErrorResponse.new(code: 401, message: 'This account has already been invited.') }, adapter: :json, status: :not_found
        else
          render json: { data: SuccessResponse.new(code: 200, message: 'Successful') }, adapter: :json, status: :ok
        end
      else
        account = Account.find_by(email: params[:resendinviteaccount], av_user_id: current_user.id)
        if (Account.where(email: params[:resendinviteaccount]).pluck(:user_status_id) & [5, 6]).any?
          render json: { data: ErrorResponse.new(code: 401, message: 'This account is associated with another ambassador/venue.') }, adapter: :json, status: :not_found
        elsif account.present?
          render json: { data: ErrorResponse.new(code: 401, message: 'This account has already been invited.') }, adapter: :json, status: :not_found
        else
          render json: { data: SuccessResponse.new(code: 200, message: 'Successful') }, adapter: :json, status: :ok
        end
      end
    end
  end

  def invite_user
    if user = User.find_by(email: params[:accountemail])
      if user.av_user.present? && user.av_user.user_status_id != 1
        render json: { data: ErrorResponse.new(code: 401, message: 'Invitation cannot be sent to this user.') }, adapter: :json, status: :not_found
      elsif user.accounts.present? && (user.accounts.pluck(:user_status_id) & [5, 6]).any?
        render json: { data: ErrorResponse.new(code: 401, message: 'This account is associated with another ambassador/venue.') }, adapter: :json, status: :not_found
      else
        invite_account(user)
      end
    else
      if (Account.where(email: params[:resendinviteaccount]).pluck(:user_status_id) & [5, 6]).any?
        render json: { data: ErrorResponse.new(code: 401, message: 'This account is associated with another ambassador/venue.') }, adapter: :json, status: :not_found
      else
        invite_account_by_mail(params[:accountemail])
      end
    end
  end

  def sign_contract
    if ambassador = AvUser.find(params[:avuserid].to_i)
      ambassador.contractSigned = params[:contractsigned]
      ambassador.user_status_id = 3
      if ambassador.save!
        update_ambassador_lt_status(ambassador.admin, ambassador, ambassador.user_status.title)
        # AvMailer.av_accepted_invite(ambassador).deliver_now
        SendAvAcceptedInviteWorker.perform_async(ambassador.id)
        render json: { data: {showContract: ambassador.showContract[:permission], contractPosition: ambassador.showContract[:position] } }, adapter: :json, status: :ok
      else
        render json: { data: ErrorResponse.new(code: 422, message: 'Unprocessable Entity') }, adapter: :json, status: :unprocessable_entity
      end
    else
      render json: { data: ErrorResponse.new(code: 401, message: 'This ambassador is not found.') }, adapter: :json, status: :not_found
    end
  end

  #set AV User Status
  def set_status
    if ambassador = AvUser.find(params[:avuserid].to_i)
      if current_user.id == ambassador.admin_id || current_user.id == ambassador.id
        ambassador.user_status_id = params[:status].to_i
        authorized_person = current_user.is_a?(AvUser) ?  ambassador.admin : current_user
        if ambassador.save!
          update_ambassador_lt_status(authorized_person, ambassador, params[:status])
          render json: { data: SuccessResponse.new(
                     code: 201, message: 'Requested status changed successfully.'
                 ) }, adapter: :json, status: :ok
        else
          render json: { data: ErrorResponse.new(code: 422, message: 'Unprocessable Entity') }, adapter: :json, status: :unprocessable_entity
        end
      else
        render json: { data: ErrorResponse.new(code: 401, message: 'This ambassador/venue is associated with another admin.') }, adapter: :json, status: :not_found
      end
    else
      render json: { data: ErrorResponse.new(code: 404, message: 'This ambassador/venue is not found.') }, adapter: :json, status: :not_found
    end
  end

  def update_stripe
    if params[:hasstripeaccount].present?
      current_user.has_stripe_linked = params[:hasstripeaccount]
      if current_user.save!
        render json: { data: SuccessResponse.new(
                   code: 201, message: 'Information Updated successfully.'
               ) }, adapter: :json, status: :ok
      else
        render json: { data: ErrorResponse.new(code: 400, message: 'Unable to Update Information.') }, adapter: :json, status: :unprocessable_entity
      end
    else
      render json: { data: ErrorResponse.new(code: 400, message: 'hasStripeAccount is required') }, adapter: :json, status: :unprocessable_entity
    end
  end

  # Summary: Invite AV User
  def invite_av
    if current_user.is_a? (Admin)
      invite_ambassador
    else
      render json: { data: ErrorResponse.new(
                 code: 400, message: 'This is a bad request.'

             ) }, adapter: :json, status: :bad_request
    end
  end

  def resend_inviteav
    if params[:profileid].present?
      if ambassador = AvUser.find_by(user_id: params[:profileid].to_i)
        if ambassador.user_status_id == 1
          association_token = AssociationToken.new(invitation_token: SecureRandom.urlsafe_base64(27),
                                                   av_user_id: ambassador.id, admin_id: current_user.id)
          association_token.save!
          # AvMailer.av_invitation(ambassador, association_token.invitation_token).deliver_now
          SendAvInvitationWorker.perform_async(ambassador.id, association_token.invitation_token)
          render json: { data: SuccessResponse.new(
                     code: 200, message: 'Success! Your invite has been sent.',

                 )}, adapter: :json, status: :ok
        else
          render json: { data: ErrorResponse.new(
                     code: 400, message: 'This ambassador/venue is associated with another admin.'

                 ) }, adapter: :json, status: :bad_request
        end
      else
        render json: { data: ErrorResponse.new(
                   code: 400, message: 'AV User Not Found',
               )}, adapter: :json, status: :not_found
      end
    else
      render json: { data: ErrorResponse.new(
                 code: 400, message: 'profileID is required.'

             ) }, adapter: :json, status: :bad_request
    end
  end

  def associate_av
    if params[:token].present?
      if token = AssociationToken.find_by(invitation_token: params[:token])
        if ambassador = AvUser.find(token.av_user_id)
          Account.where(email: ambassador.email).update_all(user_status_id: 6)
          ambassador.admin_id = token.admin_id
          ambassador.user_status_id = 2
          ambassador.save!
          create_lt_ambassador(ambassador.admin, ambassador)
          render json: { data: SuccessResponse.new(
                     code: 200, message: 'A/V associatd with the admin successfully.',

                 )}, adapter: :json, status: :ok
        else
          render json: { data: ErrorResponse.new(
                     code: 400, message: 'This ambassador/venue is associated with another admin.'

                 ) }, adapter: :json, status: :bad_request
        end
      else
        render json: { data: ErrorResponse.new(
                   code: 400, message: 'AV User Not Found',
               )}, adapter: :json, status: :not_found
      end
    else
      render json: { data: ErrorResponse.new(
                 code: 400, message: 'Token is required.'

             ) }, adapter: :json, status: :bad_request
    end
  end

  def update_av_user
    if ambassador = AvUser.find(params[:avuserid].to_i)
      ambassador.update!(update_av_user_params)
      update_lt_ambassador(current_user, ambassador)
      render json: { data: SuccessResponse.new(
                 code: 200, message: 'Updated successfully.'
             ) }, adapter: :json, status: :ok
    else
      render json: { data: ErrorResponse.new(code: 404, message: 'This ambassador/venue is not found.') }, adapter: :json, status: :not_found
    end
  end

  private

  #region Params
  def av_user_params
    params.permit(:email, :username, :fname, :lname, :phone, :address, :city, :state)
        .merge(type: params[:usertype], user_status_id: params[:userstatus], first_event_share: params[:firsteventrvshare],
               remaining_event_share: params[:remainingeventrvshare], business_name: params[:businessname],
               zip_code: params[:zipcode])
  end

  def update_av_user_params
    params.permit(:email, :username, :fname, :lname, :phone, :address, :city, :state)
        .merge(type: params[:usertype], user_status_id: params[:userstatus], first_event_share: params[:firsteventrvshare],
               remaining_event_share: params[:remainingeventrvshare], business_name: params[:businessname],
               zip_code: params[:zipcode])
  end

  def sanitize_params
    params.downcase_key
  end

  def invite_ambassador
    if member = User.find_by(email: av_user_params[:email])
      unless member.av_user.present?
        if member.type == 2
          render json: { data: ErrorResponse.new(
                     code: 404, message: 'This ambassador/venue is not found.'
                 )}, adapter: :json, status: :bad_request
        else
          av_user = AvUser.new(av_user_params)
          av_user.invitation_date = Time.now
          av_user.inv_acception_date = Time.now
          av_user.admin_id = current_user.id
          av_user.user_id = member.id
          av_user.user_status_id = 1
          av_user.first_event_share = 20.0
          av_user.remaining_event_share = 10.0
          if av_user.save_
            association_token = AssociationToken.new(invitation_token: SecureRandom.urlsafe_base64(27),
                                                     av_user_id: av_user.id, admin_id: current_user.id)
            association_token.save!
            # AvMailer.av_invitation(av_user, association_token.invitation_token).deliver_now
            SendAvInvitationWorker.perform_async(av_user.id, association_token.invitation_token)
            render json: { data: SuccessResponse.new(
                       code: 200, message: 'This ambassador/venue is associated with this admin Successfully.',
                       token: member.token

                   )}, adapter: :json, status: :created
          else
            m = ''
            # converts user.errors in to a single string
            av_user.errors.messages.each do |h|
              m += h[0].to_s
              h[1].each do |e|
                m+= ', ' + e
              end
              m+= '. '
            end
            render json: { data: ErrorResponse.new(
                       code: 400, message: 'Invalid Request',
                       errors: [{message: m}]

                   )}, adapter: :json, status: :bad_request
          end
        end
      else
        render json: { data: ErrorResponse.new(
                   code: 400, message: 'This ambassador/venue is associated with another admin.'

               ) }, adapter: :json, status: :bad_request
      end
    else
      render json: { data: ErrorResponse.new(
                 code: 404, message: 'This ambassador/venue is not found.',
             )}, adapter: :json, status: :not_found
    end
  end

  def invite_account(member=nil)
    if member.is_a? User
      unless member.av_user.present? && member.av_user.user_status_id != 1
        account = Account.find_by(email: member.email)
        account = account.present? ? account : Account.new(email: member.email)
        account.invitation_date = Time.now
        account.av_user_id = current_user.id
        account.user_id = member.id
        account.user_status_id = 1
        if account.save_
          association_token = AssociationToken.new(invitation_token: SecureRandom.urlsafe_base64(27),
                                                   av_user_id: current_user.id, account_id: account.id)
          association_token.save!
          # AvMailer.account_invitation(account, association_token.invitation_token).deliver_now
          SendAccountInvitationWorker.perform_async(account.id, association_token.invitation_token)
          render json: { data: SuccessResponse.new(
                     code: 200, message: 'Invitation sent successfully.',
                 )}, adapter: :json, status: :created
        else
          m = ''
          # converts user.errors in to a single string
          account.errors.messages.each do |h|
            m += h[0].to_s
            h[1].each do |e|
              m+= ', ' + e
            end
            m+= '. '
          end
          render json: { data: ErrorResponse.new(
                     code: 400, message: 'Invalid Request',
                     errors: [{message: m}]

                 )}, adapter: :json, status: :bad_request
        end
      else
        render json: { data: ErrorResponse.new(
                   code: 400, message: 'This account has already been invited.'

               ) }, adapter: :json, status: :bad_request
      end
    else
      render json: { data: ErrorResponse.new(
                 code: 404, message: 'Unation User Not Found',
             )}, adapter: :json, status: :not_found
    end
  end

  def invite_account_by_mail(email=nil)
    account = Account.find_by(email: email, av_user_id: current_user.id)
    # if account.present?
    #   render json: { data: ErrorResponse.new(
    #              code: 400, message: 'This account has already been invited.'
    #
    #          ) }, adapter: :json, status: :bad_request
    # else
      account = account.present? ? account : Account.new(email: email)
      account.invitation_date = Time.now
      account.av_user_id = current_user.id
      account.user_id = 999999999
      account.user_status_id = 1
      if account.save_
        association_token = AssociationToken.new(invitation_token: SecureRandom.urlsafe_base64(27),
                                                 av_user_id: current_user.id, email: email)
        association_token.save!
        # AvMailer.account_invitation_by_mail(current_user, association_token).deliver_now
        SendAccountInvitationByMailWorker.perform_async(association_token.invitation_token)
        render json: { data: SuccessResponse.new(
                   code: 200, message: 'Invitation sent successfully.',
               )}, adapter: :json, status: :created
      else
        m = ''
        # converts user.errors in to a single string
        account.errors.messages.each do |h|
          m += h[0].to_s
          h[1].each do |e|
            m+= ', ' + e
          end
          m+= '. '
        end
        render json: { data: ErrorResponse.new(
                   code: 400, message: 'Invalid Request',
                   errors: [{message: m}]

               )}, adapter: :json, status: :bad_request
      end
    # end
  end
  #endregion
end

class Hash
  def downcase_key
    keys.each do |k|
      store(k.downcase, Array === (v = delete(k)) ? v.map(&:downcase_key) : v)
    end
    self
  end
end
