class BrandsController < ApplicationController
  include BrandsHelper

  before_action :authenticate_user

  def brand_about
    user = User.find_by(id: params[:brand_id].to_i)
    if user.present?
      render json: user, serializer: BrandSerializer, current_user: current_user, status: :ok
    else
      render json: ErrorResponse.new(
        code: 404, message: 'Invalid id'
      ), adapter: :json, status: :not_found
    end
  end

   def discover
    if params[:ratio].present? && params[:ratio].to_i < 10000
      brands =
        User.without(:user_interests, :event_guest_lists)
          .where(:type.ne => 2,  :user_deleted.ne => 1, :latitude.ne => nil, :longitude.ne => nil,
                 "$or" => [{:latitude.ne => 0},{:longitude.ne => 0} ] )
    else
      brands =
        User.without(:user_interests, :event_guest_lists)
          .where(:type.ne => 2,  :user_deleted.ne => 1)
    end
    if brands.present?
      apply_brand_filters brands, true
    else
      render json: ErrorResponse.new(
        code: 404, message: 'Brands not found'
      ), adapter: :json, status: :not_found
    end
  end

  def brand_my_events
    user = User.find_by(id: params[:brand_id].to_i, :user_deleted.ne => 1)
    if user.present?
      type = params[:type].downcase
      events = nil
      is_self = user.id == current_user.id
      case type
        when 'upcoming'
          if is_self
            events = Event.without(:event_guest_lists, :event_detail).includes(:user, :event_time_zone).in(status: [1, 2])
                       .where(user_id: user.id, :start_date_time_ticks.gte => Time.now.utc)
                       .order_by(start_date_time_ticks:  'asc')
          else
            events = Event.without(:event_guest_lists, :event_detail).includes(:user, :event_time_zone).in(status: [1, 2])
                       .where(user_id: user.id, type: 'PU', :start_date_time_ticks.gte => Time.now.utc)
                       .order_by(start_date_time_ticks:  'asc')
          end
        when 'past'
          if is_self
            events = Event.without(:event_guest_lists, :event_detail).includes(:user, :event_time_zone).in(status: [1, 2])
                       .where(user_id: user.id, :start_date_time_ticks.lte => Time.now.utc)
                       .order_by(start_date_time_ticks:  'desc')
          else
            events = Event.without(:event_guest_lists, :event_detail).includes(:user, :event_time_zone).in(status: [1, 2])
                       .where(user_id: user.id, type: 'PU', :start_date_time_ticks.lte => Time.now.utc)
                       .order_by(start_date_time_ticks:  'desc')
          end
      else
        events = nil
      end
      if events.present? || events.size > 0
        render json: do_paginate( events), request: request, adapter: :json, status: :ok
      else
        render json: ErrorResponse.new(
          code: 404, message: 'No Events found!'
        ), adapter: :json, status: :not_found
      end
    else
      render json: ErrorResponse.new(
        code: 404, message: 'Invalid id'
      ), adapter: :json, status: :not_found
    end
  end

  def brand_view
    if params[:brand_id].present?
      brand_id = params[:brand_id].to_i
      user = nil
      if brand_id == 0
        user = current_user
      else
        user = User.find_by(id: brand_id)
      end
      if user.present?
        render json: user, serializer: BrandViewSerializer,
               connection: current_user.connection_with_(user), current_user: current_user, status: :ok
        return nil
      end
    end
    render json: ErrorResponse.new(
      code: 404, message: 'Invalid brand id provided'
    ), adapter: :json, status: :not_found
  end


  def brand_list_contact_groups
    type = (params[:type] == 'import')
    if type
      render json: current_user.groups.where(IsImport: 1), adapter: :json, root: 'group', status: :ok
    else
      render json: current_user.groups, root: 'group', adapter: :json, status: :ok
    end
  end

  def brand_media_album
    brand_id = params[:brand_id].to_i
    featured_only = params[:isfeatured].to_s.downcase == 'true'
    allalbumsoption = params[:allalbumsoption].to_s.downcase == 'true'
    albums = nil
    type = params[:type].to_s.downcase
    user = User.find_by(id: brand_id)

    if user.present?
      is_self = user.id == current_user.id
      if featured_only # meaning only featured albums
        album_ids = BrandMediaFolder.where(user_id: brand_id).pluck(:media_folder_id)
        albums = MediaFolder.where( :id.in => album_ids)
      else
        events_ids = Event.only(:id, :type, :status).where(user_id: user.id , type: 'PU', status: 1 ).pluck(:id)
        # uncomment to disallow everyone to see profile pics of anyone other than themselves
        #if is_self
          brand_profile_album_id = user.get_avatar_album
          albums = MediaFolder.or({id: brand_profile_album_id},{:event_id.in => events_ids} )
        #else
        #  albums = MediaFolder.in( event_id: events_ids )
        #end
        albums = albums.pluck(:id)
        photos_id = MediaItem.where(:media_folder_id.in => albums).pluck(:media_folder_id)
        albums = MediaFolder.where(:id.in => photos_id).includes(:event, :media_items) # to prevent albums with 0 photos to show up
      end
      if albums.present?
        if allalbumsoption && !featured_only # meaning 'all photos' album should be present
          albums = albums.entries
          # start of array
          albums.unshift( MediaFolder.new( id: -1, Type: albums.entries.first.album_image, Name: 'All Photos', user_id: MediaItem.in(media_folder: albums.pluck(:id)).count ))
        end
        render json: albums, root: 'media', adapter: :json, status: :ok
      else
        render json: ErrorResponse.new(
          code: 404, message: 'No almbums found'
        ), adapter: :json, status: :not_found
      end
    else
      render json: ErrorResponse.new(
        code: 404, message: 'Invalid brand_id provided'
      ), adapter: :json, status: :not_found
    end

  end

  def brand_edit
    edit
  end

  def brand_about_edit
    edit(true)
  end

  def follow_brand
    other_user = User.includes(:active_connections, :passive_connections).find_by( id: params[:brand_id].to_i)
    if other_user.present? && other_user.id != current_user.id
      current_user.follow(other_user)
      render json: SuccessResponse.new(
        code: 200, message: 'Following brand ' + other_user.id.to_s,
      ), adapter: :json, status: :ok
    else
      render json: ErrorResponse.new(
        code: 400, message: 'Invalid action'
      ), adapter: :json, status: :bad_request
    end
  end

  def unfollow_brand
    other_user = User.includes(:active_connections, :passive_connections).find_by(id: params[:brand_id].to_i)
    if other_user.present?
      current_user.unfollow(other_user)
      render json: SuccessResponse.new(
        code: 200, message: 'Un-Following brand ' + other_user.id.to_s,
      ), adapter: :json, status: :ok
    else
      render json: ErrorResponse.new(
        code: 400, message: 'Bad Request. Invalid action'
      ), adapter: :json, status: :bad_request
    end
  end

  def brand_events_available
    followed_user_ids  = current_user.following.pluck(:id).push(current_user.id).uniq
    followed_event_ids = current_user.event_guest_lists.where(subscribed: true).pluck(:event_id).uniq
    events1 =
      Event.includes(:event_uvite_own_theme, :user, :event_time_zone)
        .without(:event_categories, :event_guest_lists)
        .where( type: 'PU' , status: 1, :start_date_time_ticks.gte => Time.now.utc)
        .or( {:id.in => followed_event_ids}, {:user_id.in => followed_user_ids}  )
        .order_by(start_date_time_ticks: 'asc').limit(5000)
    _limit = 5000 - events1.size if events1.size < 5000
    events2 =
        Event.includes(:event_uvite_own_theme, :user, :event_time_zone)
          .without(:event_categories, :event_guest_lists)
          .where( type: 'PU' , status: 1, :start_date_time_ticks.lte => Time.now.utc)
          .or( {:id.in => followed_event_ids}, {:user_id.in => followed_user_ids}  )
          .order_by(start_date_time_ticks: 'desc').limit(_limit || 5000)
    events = (events1 | events2)
    if events.present?
      render json: {
        events: events.map{
          |e| FeaturedEventSerializer.new(e)
        },
        cursor:nil
      }, status: :ok
    else
      render json: ErrorResponse.new(
        code: 404, message: 'Event not found!'
      ), adapter: :json, status: :not_found
    end
  end

  def get_unation_contacts
    brands = User.where(:type.in => [0,1], :user_deleted.ne => 1)
    if brands.present?
      apply_contacts_filter brands
    else
      render json: ErrorResponse.new(
          code: 404, message: 'Brands not found'
      ), adapter: :json, status: :not_found
    end
  end

  def brand_list_connections
    type = (params[:type].present?) ? params[:type].downcase : ''
    other_user = nil
    if params[:brand_id].present?
      other_user = User.includes(:active_connections, :passive_connections).find_by( id: params[:brand_id].to_i)
    else
      other_user = current_user
    end
    users = nil
    event = nil
    is_all = false
    if other_user.present?
      other_user
      case type
        when 'connection'
          users = other_user.two_way_connections
        when 'follower'
          users = other_user.followers.sort_by{|i| i.username.downcase}
        when 'subscription'
          users = other_user.following.sort_by{|i| i.username.downcase}
        when 'contact', 'all'
          users = (type == 'all') ? other_user.all_connections : other_user.non_user_contacts
          users = fetch_members other_user, users
          if params[:eventid].present?
            event = Event.find_by(id: params[:eventid].to_i)
          end
          is_all = true
        else
          render json: ErrorResponse.new(
            code: 400, message: 'Bad Request. Invalid Type'
          ), adapter: :json, status: :bad_request
        return nil # necessary return statement, ide lies
      end

      render json: {
        contacts: users.map{
          |user| ConnectionSerializer.new(user, options = {
            connection: current_user.connection_with_(user),
            event: event, current_user: current_user, is_all: is_all
          } ) }
      }, adapter: :json, status: :ok
    else
      render json: ErrorResponse.new(
        code: 400, message: 'Invalid Profile Id'
      ), adapter: :json, status: :bad_request
    end
  end


  private
  def fetch_members(c_user, a_users)
    users = []
    a_users.entries.each do |u|
      users.push(u)
    end
    groups = Group.where(user_id: c_user.id, IsImport: 1, isPopulated: false).pluck(:id)
    if groups.present?
      dump_groups = DumpGroup.in(actual_group_id: groups)
      dump_groups.each do |dg|
        dump = dg.contacts_dump if dg.contacts_dump.present?
        if dump.present?
          dump.each do |t_user|
            user = User.new(email: t_user['email'], firstName: t_user['fullname'], type: 2, status: 5)
            users.push(user)
          end
        end
      end
    end
    users
  end
end
