class EventsController < ApplicationController
  require 'http'
  include EventsConcern

  before_action :authenticate_user, except: [:get_time_zones,
                                             :get_categories,
                                             :get_subcategories,
                                             :get_landing_page_events,
                                             :show,
                                             :get_followers,
                                            ]
  #before_action :record_api_call, only: [:discover, :get_landing_page_events]

  def create
    @event = Event.new(event_params)
    convert_timezone @event
    event_type_status @event
    if @event.save_without_exception
      update_theme @event
      add_event_categories @event
      add_event_location @event
      create_group_guest_list @event
      add_photos @event
      # Create Groups and contacts through CSV
      contacts_imports
      render json: SuccessResponse.new(
          code: 200, message: 'Event Created.', location: '/events/List?id=' + @event.id.to_s, eventID: @event.id
      ), adapter: :json, status: :ok
    else
      render json: ErrorResponse.new, adapter: :json, status: :unprocessable_entity
    end
  end

  def edit
    event = Event.find(params[:eventid].to_i)
    if event.present?
      event_type_status event, true
      if event.update(event_params)
        convert_timezone event, true
        update_theme event
        add_event_categories event, true
        add_event_location event
        edit_group_guest_list event
        add_photos event
        remove_photos event
        contacts_imports
        # Ticketing app external api call for update event on LT
        lt_update_event event
        render json: SuccessResponse.new(
            code: 200, message: 'Event Updated.', location: '/events/List?id='+event.id.to_s, eventID: event.id
        ), adapter: :json, status: :ok
      else
        render json: ErrorResponse.new, adapter: :json, status: :unprocessable_entity
      end
    else
      render json: ErrorResponse.new(code: 404, message: 'Event not found!'), adapter: :json, status: :not_found
    end
  end

  def show
    event = Event.find_by(id: params[:id].to_i)
    if event.present?
      if event.status.present? && event.status == 3
        render json: ErrorResponse.new(code: 404, message: 'Event Deleted by the Creator!', isDeleted: true),
               adapter: :json, status: :not_found
        return
      end
      ticket_url = []
      is_on_LT = (event.has_registration.present? && event.has_registration) || (event.ticket.present? && event.ticket)
      authenticate_user true
      if current_user.present?
        if event.type == 'PR'
          invited = event.event_guest_lists.where(invited: true, user_id: current_user.id).first if event.event_guest_lists.present?
          if invited.present? || event.user_id == current_user.id
            # Fetch ticket url from ticketing api
            ticket_url = fetch_ticket_url_sync event if is_on_LT
            render json: event, serializer: EventSerializer, user: current_user,
                   isView: true, ticketed: ticket_url, request: request, status: :ok
          else
            render json: ErrorResponse.new(code: 403, message: 'This event is private.'), adapter: :json, status: :forbidden
          end
        else
          ticket_url = fetch_ticket_url_sync event if is_on_LT
          render json: event, serializer: EventSerializer, user: current_user,
                 isView: true, ticketed: ticket_url, request: request, status: :ok
        end
      else
        if event.type == 'PU'
          ticket_url = fetch_ticket_url_sync event if is_on_LT
          render json: event, serializer: EventSerializer, user: nil,
                 isView: true, ticketed: ticket_url, request: request, status: :ok
        else
          render json: ErrorResponse.new(code: 403, message: 'This event is private.'), adapter: :json, status: :forbidden
        end
      end
    else
      render json: ErrorResponse.new(code: 404, message: 'Event not found!'), adapter: :json, status: :not_found
    end
  end

  def my_events
    if current_user.event_guest_lists.present?
      events = Event.without(:event_guest_lists).includes( :event_time_zone).where(user_id: current_user.id, :status.in => [1, 2])
      events = apply_sort_filter events
      apply_filters events
    else
      render json: ErrorResponse.new(code: 404, message: 'Event not found!'), adapter: :json, status: :not_found
    end
  end

  def upcoming_events
    if params[:invited].present?
      events = Event.without(:event_guest_lists, :event_detail).includes( :event_time_zone)
                    .in(id: current_user.invited_events_ids, status: [1, 2])
                    .where(:end_date_time_ticks.gte => Time.now.utc)
    else
      my_event_ids = current_user.event_guest_lists.where(:subscribed.ne => false).pluck(:event_id) | Event.only(:id).where(user_id: current_user.id, :status.in => [1,2]).pluck(:id)
      friend_ids = current_user.active_connections.pluck(:followed_id).uniq
      events =
        Event.without(:event_guest_lists, :event_detail).includes( :event_time_zone)
          .where(:end_date_time_ticks.gte => Time.now.utc, :status.in => [1,2])
          .or( {:id.in => my_event_ids}, {type: 'PU', status:1, :user_id.in => friend_ids})
    end
    if events.present?
      events = apply_sort_filter events, true
      apply_filters events, true
    else
      render json: ErrorResponse.new(code: 404, message: 'Event not found!'), adapter: :json, status: :not_found
    end
  end

  def past_events
    if params[:invited].present?
      events = Event.without(:event_guest_lists, :event_detail).includes(:event_time_zone)
                    .in(id: current_user.invited_events_ids, status: [1, 2])
                    .where(:end_date_time_ticks.lte => Time.now.utc)
    else
      my_event_ids = current_user.event_guest_lists.where(:subscribed.ne => false).pluck(:event_id) | Event.only(:id).where(user_id: current_user.id, :status.in => [1,2]).pluck(:id)
      friend_ids =   current_user.active_connections.pluck(:followed_id).uniq
      events =
        Event.without(:event_guest_lists, :event_detail).includes(:event_time_zone)
             .where(:end_date_time_ticks.lte => Time.now.utc, :status.in => [1,2])
             .or( {:id.in => my_event_ids}, {type: 'PU', status:1, :user_id.in => friend_ids} )
    end
    if events.present?
      events = apply_sort_filter events
      apply_filters events
    else
      render json: ErrorResponse.new(code: 404, message: 'Event not found!'), adapter: :json, status: :not_found
    end
  end

  def discover
    events = Event.without(:event_guest_lists, :event_detail).
      where(
        :start_date_time_ticks.gte => Time.now.utc,
        status: 1,
        type: 'PU',
        :location.exists => true
      )
    if params[:autostaffpick].present?
      apply_auto_staff_picked_filter events
    else
      apply_filters events, true
    end
  end

  def get_time_zones
    time_zones = EventTimeZone.get_all
    render json: time_zones, root: 'timezones', adapter: :json, status: :ok
  end


  # Summary: Get all event categories
  # params: id
  # This api will return parent categories
  # It is finding categories from taxonomies collection by parent id = null

  def get_categories
    categories = Taxonomy.get_categories
    render json: categories, root: 'categories', adapter: :json, status: :ok
  end

  # Summary: Get all event subcategories
  # params: id
  # This api will return sub categories
  # It is finding categories from taxonomies collection by parent id is not null

  def get_subcategories
    sub_categories = Taxonomy.get_subcategories
    render json: sub_categories, root: 'categories', adapter: :json, status: :ok
  end

  def update_staff_pick
    event = Event.find_by(id: params[:eventid].to_i)
    staffpick = (params[:isstaffpicked] == 1 || params[:isstaffpicked] == true) ? 1 : 0
    if event.present? && current_user.isStaffMember.present? && current_user.isStaffMember
      if params.has_key?(:isstaffpicked)
        event.update(is_staff_picked: staffpick)
        # Ticketing app external api call
        if event.type == 'PU' && staffpick == 1
          lt_update_staff_pick_event event, true
        elsif event.type == 'PU' && staffpick == 0
          lt_update_staff_pick_event event, false
        end
        Event.clear_landing_page_cache()
        render json: SuccessResponse.new( data:{success: true} ), adapter: :json, status: :ok
      else
        render json: ErrorResponse.new, adapter: :json, status: :bad_request
      end
    else
      render json: ErrorResponse.new( data:{success: false} ), adapter: :json, status: :bad_request
    end
  end

  def update_hide_attendance
    event = Event.find_by(id: params[:eventid].to_i)
    if event.present?
      guest = event.event_guest_lists.where(user_id: current_user.id)
      if params[:option] == 'yes'
        guest.update(hide_attendance: 1)
        render json: SuccessResponse.new( code: 200 ), adapter: :json, status: :ok
      elsif params[:option] == 'no'
        guest.update(hide_attendance: 0)
        render json: SuccessResponse.new( code: 200 ), adapter: :json, status: :ok
      else
        render json: ErrorResponse.new, adapter: :json, status: :bad_request
      end
    else
      render json: ErrorResponse.new, adapter: :json, status: :bad_request
    end
  end

  # Summary: Get Status of Hidden Attendees
  # This api is searching hidden attendees by receiving event id through params
  # If the event is not present then it returns false, bad_request
  # otherwise it returns True message with status ok

  def get_hide_attendance
    event = Event.find_by(id: params[:eventid].to_i)
    if event.present?
      guest = event.event_guest_lists.where(user_id: current_user.id).first
      if guest.present? && guest.hide_attendance == 1
        render json: SuccessResponse.new(code: 200, message: 'True'), adapter: :json, status: :ok
      else
        render json: ErrorResponse.new(code: 400, message: 'False'), adapter: :json, status: :bad_request
      end
    else
      render json: ErrorResponse.new(code: 404, message: 'Event not found'), adapter: :json, status: :not_found
    end
  end
  
  def perform_rsvp
    do_perform_rsvp
  end

  def get_followers
    do_get_followers
  end

  def follow_event
    act_on_event params[:eventid], true
  end

  def un_follow_event
    act_on_event params[:eventid], false
  end

  def get_landing_page_events
    events = Event.where(:start_date_time_ticks.gte => Time.now.utc, status: 1, type: 'PU', is_staff_picked: 1)

    range = params[:ratio].to_i
    if params[:ratio].present? && range > 100
      render json: ErrorResponse.new(code: :bad_request, message: 'Radius cant be greater than 100'),
             adapter: :json, status: :bad_request
    else
      if params[:ratio].present?
        events = filter_by_location params[:latitude], params[:longitude], events, range
      else
        events = filter_by_location params[:latitude], params[:longitude], events, 50
      end
      events = events.uniq.sort_by! {|obj| obj.start_date_time_ticks  unless obj.blank?}
      events = do_paginate(events , PAGE_ENTITY[:events], false, 'landingPage' )
      if events.present? && events.events.size > 0
        render json: events, request: request, root: 'data', adapter: :json, status: :ok
      else
        render json: ErrorResponse.new(code: 404, message: 'Event not found!'), adapter: :json, status: :not_found
      end
    end
  end

  # Summary: Cancel Event
  # This api search event to be cancelled through eventId as params
  # If the event is present then it updates its status to 2 and displays success response of Event cancelled with status ok (200)
  # If the event is not in the list then it displays the message that event not found with status not found (404)

  def cancel_event
    event = Event.find_by(id: params[:eventid].to_i)
    if event.present? && event.user_id == current_user.id
      event.update(status: 2)
      lt_update_event_status event, 'Canceled'
      render json: SuccessResponse.new(
          code: 200,
          message: 'Event cancelled.'
      ), adapter: :json, status: :ok
    else
      render json: ErrorResponse.new(
          code: 404,
          message: 'Event not found!'
      ), adapter: :json, status: :not_found
    end
  end

  # Summary: Delete Event
  # Description:
  # This api first searches the event to be deleted through eventId as search params
  # If the event is present in the collection of Events then it will be selected and its status is updated to 3 with
  # showing success response with message "Event Deleted" and status ok (200)
  # If the event is not present then it displays the message "Event not found" with status not found (404)
  # and no action is performed

  def delete_event
    event = Event.find_by(id: params[:eventid].to_i)
    if event.present?
      event.update(status: 3)
      lt_update_event_status event, 'archived'
      render json: SuccessResponse.new(
          code: 200,
          message: 'Event Deleted.'
      ), adapter: :json, status: :ok
    else
      render json: ErrorResponse.new(
          code: 404,
          message: 'Event not found!'
      ), adapter: :json, status: :not_found
    end

  end

end
