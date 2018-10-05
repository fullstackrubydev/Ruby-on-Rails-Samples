class FeaturedEventSerializer < ActiveModel::Serializer

  require 'date'
  attribute :id, key: :eventID
  attribute :name
  attribute :startDateTime
  attribute :endDateTime


  attributes :themeUrl,  :thumbnailUrl,  :username,  :distance,  :timezone, :isStaffPicked

  # def self.serializer_for(model, options)
  #   if object.user.present? && object.user.user_privacy == nil
  #     object.user.create_privacy
  #   end
  #   super
  # end

  def  themeUrl
    Rails.application.config.resize_cdn_url + object.get_theme
  end
  def  thumbnailUrl
    Rails.application.config.resize_cdn_url + object.get_theme_thumb
  end
  def  username
    if object.user.present?
      object.user.username
    else
      ''
    end
  end
  def  distance
    nil
  end
  def  timezone
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

  def  isStaffPicked
    object.is_staff_picked == 1
  end

  def endDateTime
    timezone_offset = object.get_timezone_offset
    if timezone_offset.present?
      if object.end_date_time_ticks.present?
        datetime = object.convert_with_timezone timezone_offset, object.end_date_time_ticks
        datetime.strftime('%Y-%m-%dT%H:%M:%S')
      end
    else
      object.end_date_time_ticks.strftime('%Y-%m-%dT%H:%M:%S') if object.end_date_time_ticks.present?
    end
  end

  def startDateTime
    timezone_offset = object.get_timezone_offset
    if timezone_offset.present?
      if object.start_date_time_ticks.present?
        datetime = object.convert_with_timezone timezone_offset, object.start_date_time_ticks
        datetime.strftime('%Y-%m-%dT%H:%M:%S')
      end
    else
      object.start_date_time_ticks.strftime('%Y-%m-%dT%H:%M:%S') if object.start_date_time_ticks.present?
    end
  end


end
