class ApplicationController < ActionController::API
  require 'will_paginate/array'
  require 'cgi'
  require 'http'

  require 'openssl'
  require 'base64'
  require 'digest/md5'

  require 'api_hit_worker'

  before_action :authenticate_client
  before_action :sanitize_params

  attr_accessor :current_user

  # possible symbols for pagination
  PAGE_ENTITY={events:0, brands_discover:1, event_media_photos:2, unation_contacts:3}
  PAGINATION_LIMIT = 25

  #region methods

  # summary: only allow those clients that have the client id and secret in their request_headers
  # params: token from header
  # note: rails automatically converts '_' to '-' in headers

  def authenticate_client
    client_id = request.headers['client-id']
    client_secret = request.headers['client-secret']

    unless client_id == Rails.application.secrets.api_key && client_secret == Rails.application.secrets.api_secret
      render json: ErrorResponse.new(
          code: 401, message: 'Unauthorized Request'
      ), adapter: :json, status: :unauthorized
      nil
    end

  end

  # summary: Set the current_user attribute to the user found using the request token
  # params: token from header

  def authenticate_user (temp = false)
    token = request.headers['token']
    user_token = Token.find_by(access_token: token)
    @current_user = nil
    if params[:hashtoken].present?
      if params[:id].present?
        hash_token = TokenEventInvite.where(access_token: params[:hashtoken], event_id: params[:id].to_i).first
        if hash_token.present?
          user_id = hash_token.user_id
          @current_user = User.find_by(id: user_id)
        else
          @current_user = authenticate_old_event( params[:hashtoken], params[:id].to_i)
        end
      else
        hash_token = TokenUserConfirmation.where(access_token: params[:hashtoken]).first ||
                     TokenPasswordReset.where(access_token: params[:hashtoken]).first
        if hash_token != nil
          user_id = hash_token.user_id
          @current_user = User.find_by(id: user_id)
        else
          render json: ErrorResponse.new(
              code: 401, message: 'Missing token. Authorization has been denied for this request.'
          ), adapter: :json, status: :unauthorized unless temp
          return nil
        end
      end
    elsif user_token.present?
      user_id = user_token.user_id
      @current_user = User.find_by(id: user_id)
      if @current_user.present? && request.path.include?("/ambassador/")
        @current_user = @current_user.admin.present? ? @current_user.admin : @current_user.av_user
      end
    else
      if token.present?
        @current_user = authenticate_old( token)
        if @current_user.present?
          if @current_user.present? && request.path.include?("/ambassador/")
            @current_user = @current_user.admin.present? ? @current_user.admin : @current_user.av_user
          end
          return nil
        else
          render json: ErrorResponse.new(
                     code: 401, message: 'User not found. Authorization has been denied for this request.'
                 ), adapter: :json, status: :unauthorized unless temp
          return nil
        end
      end
      render json: ErrorResponse.new(
          code: 401, message: 'Missing token. Authorization has been denied for this request.'
      ), adapter: :json, status: :unauthorized unless temp
      return nil
    end
    if @current_user.blank?
      render json: ErrorResponse.new(
          code: 401, message: 'Bad Request: User not found'
      ), adapter: :json, status: :unauthorized unless temp
      nil
    end
  end

  def do_paginate (entity, entity_type=PAGE_ENTITY[:events], is_discover = false, spsc = '')
    if entity.blank?
      return nil
    end
    page_limit = PAGINATION_LIMIT
    page_num = (params[:cursor].present?)? params[:cursor].to_i : 1
    page_num = (page_num >= 1)? page_num : 1
    total_count = entity.count
    current_page_count = entity.paginate(page: page_num, per_page: page_limit).size
    has_previous = (page_num > 1)
    has_next = ((current_page_count == page_limit) && (total_count > page_limit * page_num))
    prev_link = next_link = ''
    if request.original_url.include? 'cursor='
      uri    = URI.parse(request.original_url)
      query_params = CGI.parse(uri.query)
      arr = request.original_url.split('cursor='+query_params['cursor'].first)
      prev_link = arr[0] + 'cursor=' + (page_num - 1).to_s + arr[1].to_s if (has_previous)
      next_link = arr[0] + 'cursor=' + (page_num + 1).to_s + arr[1].to_s if (has_next)
    else
      next_link = request.original_url + '&cursor=' + (page_num + 1).to_s if (has_next)
    end
    cursor = {
      cursor: {
        prev: (has_previous)? (page_num - 1).to_s : '',
        next: (has_next)? (page_num + 1).to_s : '',
        hasPrev: (has_previous),
        hasNext: (has_next)
      },
      link: {
        prev: prev_link,
        next: next_link
      }
    }
    #end
    case entity_type
      when PAGE_ENTITY[:events]
        isLPE = spsc === 'landingPage'
        EventIndex.new(
            events: entity.paginate(page: page_num, per_page: page_limit).map{ |event|
              EventSerializer.new(event, options= {
                  user: current_user,
                  distance: event.geo_near_distance || nil,
                  isLandingPageEvents: isLPE
              })
            },
            cursor: cursor,
            showPopup: false,
            staffPickSearchCriteria: spsc
        )

      when PAGE_ENTITY[:event_media_photos]
        {
          media: entity.paginate(page: page_num, per_page: page_limit).map{
            |media_i| EventMediaPhotoSerializer.new(media_i)
          },
          cursor: cursor
        }

      when PAGE_ENTITY[:brands_discover]
        paginated_brands = entity.paginate( page: page_num, per_page: page_limit)
        arr = paginated_brands.group_by{|a| a.geo_near_distance.to_f.round(1)}
        result = []
        arr.map {|k,v|
          result += v.sort {|a, b| b.followers_count <=> a.followers_count}
        }
        {
          brands: result.map{ |brand|
            BrandDiscoverSerializer.new(brand, options= {
                distance: brand.geo_near_distance || nil,
                followers_count: brand.followers_count,
                connection: current_user.connection_with_(brand),
                is_discover: is_discover,
                current_user: current_user
            })
          },
          cursor: cursor,
          showPopup: false
        }
      when PAGE_ENTITY[:unation_contacts]
        {
          brands: entity.map{ |brand|
            UnationContactsSerializer.new( brand, options= { current_user: current_user, connection: current_user.connection_with_(brand) } ) },
          cursor: cursor,
          showPopup: false
        }
      else
        nil
    end
  end

  def sanitize_params
    params.downcase_key
  end

  def authenticate_super_admin
    token = request.headers['token']
    user_token = Token.find_by(access_token: token)
    @current_user = nil

    if user_token.present?
      @current_user = Admin.find_by(user_id: user_token.user_id)

      if !@current_user.present? && @current_user.super_admin == false
        @current_user = nil
      end

    end

    if @current_user.blank?
      render json: ErrorResponse.new(
          code: 401, message: 'Authorization has been denied for this request.'
      ), adapter: :json, status: :bad_request
      nil
    end
  end
  #endregion

  private

  def authenticate_old( token)
    des = OpenSSL::Cipher::Cipher.new("des-ede3")
    des.decrypt
    key = Digest::MD5.digest('u9&7kKyW21Gr3M10|7R1c0LoR-1m0T@L')
    key += key[0..8]
    des.key = key

    encrypted_data = Base64.decode64( token)
    decrypted = des.update(encrypted_data)
    dec_user_id = decrypted[/&.*&(.*?)&[^&]*/m, 1]

    User.includes(:active_connections, :passive_connections, :contacts).find_by( user_id_legacy: dec_user_id.to_s.strip.to_i)
  end

  def record_api_call
    toggle = RedisService.get('report_switch')['status'] == 'on' rescue true
    if toggle
      req = {
        ip:           request.remote_ip,
        port:         request.headers['REMOTE_PORT'],
        user_agent:   request.headers['HTTP_USER_AGENT'],
        end_point:    request.headers['PATH_INFO'],
        query_string: request.headers['QUERY_STRING'],
        time:         Time.now.utc
      }

      req.merge!( ratio:    params[:ratio].to_i)              if params[:ratio].present?
      req.merge!( lat:      params[:latitude].to_f.round(4))  if params[:latitude].present?
      req.merge!( lng:      params[:longitude].to_f.round(4)) if params[:longitude].present?
      req.merge!( user_id:  current_user.id)                  rescue nil
      #(ApiVisit.new req).save!
      ApiHitWorker.perform_async(req, Time.now.utc)
    end
  end

  def authenticate_old_event( token, event_id)
    des = OpenSSL::Cipher::Cipher.new("des-ede3")
    des.decrypt
    key = Digest::MD5.digest('u9&7kKyW21Gr3M10|7R1c0LoR-1m0T@L')
    key += key[0..8]
    des.key = key

    encrypted_data = Base64.decode64( Base64.decode64( token) )
    decrypted = des.update(encrypted_data)
    dec_user_id = decrypted[/^(.*?)-/m, 1].to_i
    dec_event_id = decrypted[/-(.*?)-$/m, 1].to_i

    if event_id.to_i == dec_event_id
      User.includes(:active_connections, :passive_connections,  :contacts).find_by( user_id_legacy: dec_user_id)
    else
      nil
    end
  end

end


class Hash
  def downcase_key
    keys.each do |k|
      store(k.downcase, Array === (v = delete(k)) ? v.map(&:downcase_key) : v)
    end
    self
  end
end

class String
  def string_between_markers marker1, marker2
    self[/#{Regexp.escape(marker1)}(.*?)#{Regexp.escape(marker2)}/m, 1]
  end
end
