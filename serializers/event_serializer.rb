class EventSerializer < ActiveModel::Serializer

  require 'date'
  attribute :id
  attribute :name
  attribute :themeURL             # from EventTheme
  attribute :themeUrl             # from EventTheme # duplicated for ios
  attribute :themeID              # from EventTheme
  attribute :thumbnailURL         # from EventTheme
  attribute :thumbnailUrl         # from EventTheme # duplicated for ios
  attribute :subscribed           # is current user subscribe
  attribute :ageRestriction
  attribute :isAllDay
  attribute :isOwnTheme
  attribute :saveGuestGroup
  attribute :updateGuestGroup
  attribute :ticket
  attribute :ticketPrice
  attribute :ticketPurchaseUrl    # from ticketing api
  attribute :ticketPurchaseUrlLT  # from ticketing api
  attribute :call_to_action_id, key: :callToActionId
  attribute :currentUserRsvp      # current user RSVP
  attribute :isStaffPicked
  attribute :website
  attribute :hashtag
  attribute :tags
  attribute :createdBy

  attribute :profileCreatedBy
  attribute :type
  attribute :categories
  attribute :style
  attribute :description
  attribute :status
  attribute :startDateTime
  attribute :startDate
  attribute :endDateTime
  attribute :endDate
  attribute :distance              # from current user
  attribute :timezone
  attribute :inviteeProfileId
  attribute :countRecommendation
  attribute :countComments
  attribute :countPhotos
  attribute :countVideos
  attribute :theme
  attribute :profile
  attribute :environmentUrl
  #attribute :event_followers_count, key: :followers
  attribute :followers
  attribute :event_guests_count, key: :countGuest
  attribute :id, key: :eventID
  # attribute :event_categories, key: :categories
  # attribute :createdBY, key: :createdby
  has_one :event_location, key: :address

  def followers
    if instance_options[:isView]
      #object.media_folder.media_items.count.to_i rescue 0
      begin
        ids = object.event_guest_lists.where(subscribed: true, :hide_attendance.ne => 1).pluck(:user_id)
        User.only(:id, :type, :email).where(:id.in => ids, :type.in =>[0,1]).count
      rescue
        0
      end
    else
      0
    end
  end

  def theme
    if instance_options[:isLandingPageEvents]
      {
        id: 0,
        color: nil,
        css: nil,
        url: Rails.application.config.resize_cdn_url + object.get_theme,
        thumb: Rails.application.config.resize_cdn_url + object.get_theme_thumb,
        isOwn: object.event_theme.present? || (object.is_own_theme == true) # can be nil
      }
    else
      nil
    end
  end

  def environmentUrl
    Rails.application.config.web_client_url + '/event/' + object.id.to_s
  end

  def profile
    user = User.without(:user_privacy,:user_interests ,:event_guest_lists).find_by(id: object.user_id.to_i)
    if user.present?
      name = (user.firstName.present?)? user.firstName.to_s + ' ' + user.lastName.to_s : nil
      {
        profileID: user.id,
        fullName: (user.type == 1)? nil : name,
        displayName:  user.username,
        avatarThumb: Rails.application.config.resize_cdn_url + user.get_avatar
      }
    else
      {
        profileID: -1,
        fullName: '',
        displayName:  '',
        avatarThumb: ''
      }
    end
  end
  def profileCreatedBy
    user = User.without(:user_privacy,:user_interests ,:event_guest_lists).find_by(id: object.user_id.to_i)
    if user.present?
      name = (user.firstName.present?)? user.firstName.to_s + ' ' + user.lastName.to_s : nil
      {
        profileID: user.id,
        fullName: (user.type == 1)? nil : name,
        displayName:  user.username,
        avatarThumb: Rails.application.config.resize_cdn_url + user.get_avatar
      }
    else
      {
        profileID: -1,
        fullName: '',
        displayName:  '',
        avatarThumb: ''
      }
    end
  end

  def inviteeProfileId
    if instance_options[:user].present?
      instance_options[:user].id
    else
      0
    end
  end
  def countRecommendation
    0
  end
  def countComments
    0
  end
  def countVideos
    0
  end

  def distance
    instance_options[:distance]
  end

  def countPhotos
    if instance_options[:isView]
      object.media_folder.media_items.count.to_i rescue 0
    else
      0
    end
  end

  def themeID
    if object.event_theme.present?
      return object.event_theme.id
    end
    if object.is_own_theme == true
      return object.uvite_own_theme_id
    else
      return object.theme_id
    end
  end

  def isOwnTheme
    object.event_theme.present? || (object.is_own_theme == true)
  end

  def themeURL  #acceptanceresize.unation.com/util +/getresi
    Rails.application.config.resize_cdn_url + object.get_theme
  end

  def thumbnailURL
    Rails.application.config.resize_cdn_url + object.get_theme_thumb
    #'http://192.168.0.149' + '/util/getResizedImage?URL=' + object.get_theme_thumb
    #'https://stg-cdn.unation.com/getResizedImage?URL=http://qa-cdn.unation.com/img/themes/Default_Mobile/default_mobile_thumb.jpg'
  end

  def themeUrl
    Rails.application.config.resize_cdn_url + object.get_theme
    #'http://192.168.0.149' + '/util/getResizedImage?URL=' + object.get_theme
  end

  def thumbnailUrl
    Rails.application.config.resize_cdn_url + object.get_theme_thumb
    #'http://192.168.0.149' + '/util/getResizedImage?URL=' + object.get_theme_thumb
    #'https://stg-cdn.unation.com/getResizedImage?URL=http://qa-cdn.unation.com/img/themes/Default_Mobile/default_mobile_thumb.jpg'
  end

  def currentUserRsvp
    if instance_options[:user].present? && instance_options[:isView].present? && instance_options[:isView]
      gl = object.event_guest_lists.find_by(user_id: instance_options[:user].id)
      if gl != nil
        case gl.rsvp
          when 10
            'Yes'
          when 11
            'No'
          when 12
            'Maybe'
          else
            nil
        end
      else
        nil
      end
    else
      nil
    end
  end

  def ticket
    instance_options[:ticketed].present? && ( [1,2].include?(instance_options[:ticketed][1]) )
  end

  def ticketPurchaseUrlLT
    (instance_options[:ticketed].present?) ? instance_options[:ticketed][0] : nil
  end

  def subscribed
    u = instance_options[:user]
    if u.present?
      u.event_guest_lists.where(event_id: object.id, subscribed: true).first.present?
    else
      false
    end
  end

  def status
    case object.status
      when 1
        'Published'
      when 2
        'Canceled'
      when 3
        'Deleted'
      else # 0
        'Draft'
    end
  end
  def categories
    # needs refactoring here...
    categories = []
    object.event_categories.each do |cat|
      category = Taxonomy.get_by_id(cat.category_id)  if cat.category_id.present?
      subCategory = Taxonomy.get_by_id(cat.sub_category_id) if cat.sub_category_id.present?
      if category.present? && subCategory.present?
        categories.push({ category: EventCategorySerializer.new(category), subCategory: EventCategorySerializer.new(subCategory)})
      end
    end
    categories
  end

  def createdBy
    object.user_id
  end

  def timezone
    tz = object.get_timezone_offset
    if tz.present?
      {
          id: tz[3].name,
          description: tz[3].description,
          offset: (tz[0]+tz[1].to_s).to_i
      }
    else
      {
          id: 'Eastern Standard Time',
          description: '(UTC-05:00) Eastern Time (US & Canada)',
          offset: -5
      }
    end
  end

  def type
    type = nil
    if object.type == 'PU'
      type = 'Public'
    elsif object.type == 'PR'
      type = 'Private'
    end
    type
  end

  def saveGuestGroup
    object.save_guest_group == 1 || object.save_guest_group == true
  end

  def updateGuestGroup
    object.update_guest_group == 1 || object.update_guest_group == true
  end

  def ageRestriction
    if object.age_restriction.present?
      if object.age_restriction.to_s.include?('18')
        18
      elsif object.age_restriction.to_s.include?('21')
        21
      else
        0
      end
    else
      0
    end
  end

  def isAllDay
    object.all_day == 1
  end

  def ticketPrice
    tp = object.ticket_price
    if tp == 0.0 || tp == 0
      0.0000
    else
      tp
    end
  end

  def ticketPurchaseUrl
    object.ticket_purchase_url
  end

  def callToActionId
    object.call_to_action_id
  end

  def isStaffPicked
    object.is_staff_picked == 1
  end

  def startDate
    timezone_offset = object.get_timezone_offset
    if timezone_offset.present?
      if object.start_date_time_ticks.present?
        # datetime = object.convert_datetime object.start_date_time_ticks, timezone_offset
        datetime = object.convert_with_timezone timezone_offset, object.start_date_time_ticks
        datetime.strftime('%Y-%m-%dT%H:%M:%S')
      end
    else
      object.start_date_time_ticks.strftime('%Y-%m-%dT%H:%M:%S') if object.start_date_time_ticks.present?
    end
  end

  def endDate
    timezone_offset = object.get_timezone_offset
    if timezone_offset.present?
      if object.end_date_time_ticks.present?
        # datetime = object.convert_datetime object.end_date_time_ticks, timezone_offset
        datetime = object.convert_with_timezone timezone_offset, object.end_date_time_ticks
        datetime.strftime('%Y-%m-%dT%H:%M:%S')
      end
    else
      object.end_date_time_ticks.strftime('%Y-%m-%dT%H:%M:%S') if object.end_date_time_ticks.present?
    end
  end

  def startDateTime
    #Time.at(object.start_date_time_ticks/1000).to_datetime
    timezone_offset = object.get_timezone_offset
    if timezone_offset.present?
      if object.start_date_time_ticks.present?
        # datetime = object.convert_datetime object.start_date_time_ticks, timezone_offset
        datetime = object.convert_with_timezone timezone_offset, object.start_date_time_ticks
        datetime.strftime('%Y-%m-%dT%H:%M:%S')
      end
    else
      object.start_date_time_ticks.strftime('%Y-%m-%dT%H:%M:%S') if object.start_date_time_ticks.present?
    end
  end

  def endDateTime
    #Time.at(object.end_date_time_ticks/1000).to_datetime
    timezone_offset = object.get_timezone_offset
    if timezone_offset.present?
      if object.end_date_time_ticks.present?
        # datetime = object.convert_datetime object.end_date_time_ticks, timezone_offset
        datetime = object.convert_with_timezone timezone_offset, object.end_date_time_ticks
        datetime.strftime('%Y-%m-%dT%H:%M:%S')
      end
    else
      object.end_date_time_ticks.strftime('%Y-%m-%dT%H:%M:%S') if object.end_date_time_ticks.present?
    end
  end

end

