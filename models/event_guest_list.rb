class EventGuestList
  include Mongoid::Document
  include Mongoid::Timestamps
  field :user_id
  field :event_id
  field :action
  field :rsvp
  field :subscribed # boolean
  field :invite_type
  field :invite_date
  field :action_date
  field :invited # boolean
  field :is_email_sent
  field :hide_attendance
  field :recommended
  field :publish_uwall

  embedded_in :user
  embedded_in :event

  before_create do
    max = 999999999
    min = 100000000
    self.id = rand(max - min) + min
  end

end