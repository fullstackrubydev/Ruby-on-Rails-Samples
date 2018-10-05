class Event

  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Search

  include RandomNumberIdentifier
  # region Constants
  # endregion

  # region Fields
  #increments :id, seed: 8534592
  field :name
  field :description
  field :start_date_time_ticks
  field :end_date_time_ticks
  field :timezone_off_set
  field :timezone_name
  field :status
  field :type

  field :content_id
  field :age_restriction,                 default: 0
  field :allow_non_members
  field :all_day
  # field :hide_attendee  # not used yet
  field :user_id
  field :theme_id,                         default: 8170    # default theme
  field :uvite_own_theme_id
  field :style
  field :created_by
  field :updated_by
  field :ticket_price,                    type: Float
  field :ticket_purchase_url
  field :tags
  field :website
  field :hashtag
  field :ticket,                          default: false
  field :save_guest_group,                default: false
  field :update_guest_group,              default: false
  field :guest_group_id
  field :has_registration,                default: false
  field :call_to_action_id
  field :is_staff_picked,                 default: 0
  field :is_own_theme,                    default: false
  field :publish
  field :invite
  field :keywords,                        default: ''
  field :event_followers_count,           type: Integer, default: 0
  field :event_guests_count,              type: Integer, default: 0
  field :location,                        type: Array     # first is longitude second is latitude

  field :geo_near_distance

  search_in :name, :description, :keywords, :hashtag, :tags, :user => :username
  # endregion

  # region Associations
  belongs_to :user
  belongs_to :event_time_zone,        optional: true, primary_key: :timezone_name,      foreign_key: :timezone_name
  belongs_to :event_uvite_own_theme,  optional: true, primary_key: :uvite_own_theme_id, foreign_key: :uvite_own_theme_id
  belongs_to :event_uvite_theme,      optional: true, primary_key: :theme_id,           foreign_key: :theme_id

  has_one :media_folder

  embeds_many :event_categories
  embeds_one :event_detail
  embeds_one :event_location
  embeds_one :event_theme
  embeds_many :event_guest_lists
  # embeds_many :event_user_options # not in use
  # endregion

  @@LandingPage = {}

  # region Validations
  # endregion

  # region Indexes
  index({ user_id: 1 })
  #index({ status: 1 })
  #index({ type: 1 })
  #index({ is_staff_picked: 1 })
  index({ start_date_time_ticks: 1 })
  index({ end_date_time_ticks: 1 })
  index({ location: "2dsphere" })
  index({ status:1, type: 1, is_staff_picked: 1})
  # endregion

  # region Callbacks
  after_initialize do
    if self.event_location.blank?
      EventLocation.create!(event: self)
    end
  end

  before_create do
    max = 999999999
    min = 100000000
    self.id = rand(max - min) + min
  end

  # endregion

  # region methods
  def event_guests_count
    event_guest_lists.where(rsvp: 10).pluck(:user_id).uniq.count
  end

  def get_theme
    begin
      e = Rails.application.config.default_image
      if self.event_theme.present? && self.event_theme.theme_url.present?
        e = Rails.application.config.cdn_url + ((event_theme.theme_url[0] == '/') ? event_theme.theme_url : "/#{event_theme.theme_url}")
      end
      if self.is_own_theme && self.uvite_own_theme_id.present?
        x = self.event_uvite_own_theme.get_image rescue nil #EventUviteOwnTheme.find_by(id: self.uvite_own_theme_id).get_image rescue nil
      elsif self.theme_id.present? && (![0,8170].include?(self.theme_id))
        #x = EventUviteTheme.find_by(id: self.theme_id).get_image rescue nil
        x = self.event_uvite_theme.get_image rescue nil
      end
     return (x || e)
    rescue NoMethodError
      Rails.application.config.default_image
    end
  end

  def get_theme_thumb
    begin
      e = Rails.application.config.default_image
      if self.event_theme.present? && self.event_theme.thumbnail_url.present?
        e = Rails.application.config.cdn_url + ((event_theme.thumbnail_url[0] == '/') ? event_theme.thumbnail_url : "/#{event_theme.thumbnail_url}")
      end
      if self.is_own_theme && self.uvite_own_theme_id.present?
        x = self.event_uvite_own_theme.get_image_thumb rescue nil #EventUviteOwnTheme.find_by(id: self.uvite_own_theme_id).get_image_thumb rescue nil
      elsif self.theme_id.present? && (![0,8170].include?(self.theme_id))
        x = self.event_uvite_theme.get_image_thumb rescue nil
      end
      return (x || e)
    rescue NoMethodError
      Rails.application.config.default_image
    end
  end

  def get_timezone_offset
    result = nil
    timezone = EventTimeZone.get_by_id(self.timezone_name)#self.event_time_zone
    if timezone.present? && timezone.description.present?
      str = StringHelper.get_string_between '(UTC', ')', timezone.description
      hm = str.split(':')
      sign = hm[0][0] if hm.present?
      hours = hm[0][1,2].to_i if sign.present?
      min = hm[1].to_i if hours.present?
      if sign.present? && hours.present? && min.present?
        result = [sign, hours, min, timezone]
      end
    end
    result
  end

  def get_timezone_offset_create(time)
    result = nil
    timezone = self.event_time_zone
    if timezone.present? && timezone.description.present?
      str = StringHelper.get_string_between '(UTC', ')', timezone.description
      hm = str.split(':')
      sign = hm[0][0] if hm.present?
      s = timezone.description.slice(12..-1).strip.split(',').first
      t = time.in_time_zone(s).time
      seconds_diff = (time - t).to_i.abs
      hours = seconds_diff / 3600
      seconds_diff -= hours * 3600
      min = seconds_diff / 60
      if sign.present? && hours.present? && min.present?
        result = [sign, hours.to_i, min.to_i, timezone]
      end
    end
    result
  end

  def convert_with_timezone(timezone, time)
    begin
      tz = timezone[3].description
      s = tz.slice(12..-1).strip.split(',').first
      time.in_time_zone(s)
    rescue
      time
    end
  end

  def convert_datetime (date_time, offset, revert = false)
    if offset[0] == '-'
      if revert
        date_time + offset[1].hours + offset[2].minutes
      else
        date_time - offset[1].hours + offset[2].minutes
      end
    else
      if revert
        date_time - offset[1].hours + offset[2].minutes
      else
        date_time + offset[1].hours + offset[2].minutes
      end
    end
  end

  # endregion

  def self.get_landing_page(range, lat,lng)
    key = "#{range}_#{lat}_#{lng}"
    if @@LandingPage[key].nil? || @@LandingPage[key][0] < (Time.now - 30.minutes)
      events = Event.without(:event_guest_lists, :event_categories, :event_detail)
                 .includes(:event_time_zone, :event_uvite_own_theme,:event_uvite_theme)
                 .includes(:user ,with: ->(user) { user.only(:email,:username)})
                 .where(:start_date_time_ticks.gte => Time.now.utc, status: 1, type: 'PU', is_staff_picked: 1)
      events = EventFilters.location( events, lat, lng, range)
      events = EventFilters.sort(events, 'asc')
      @@LandingPage[key] = [Time.now, events.entries]
    end
    @@LandingPage[key][1]
  end

  def self.clear_landing_page_cache()
    @@LandingPage = {}
  end

end
