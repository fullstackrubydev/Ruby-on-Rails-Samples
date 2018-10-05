class EventUserOption
  include Mongoid::Document

  field :user_id
  field :event_id
  field :recommended
  field :publish_uwall
  field :subscribed
  field :rsvp
  field :hide_from_calendar
  field :restriction_accepted
  field :hide_attendance

# embedded_in :event

end
