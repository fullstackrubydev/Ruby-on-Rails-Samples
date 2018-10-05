class EventActionStatus
  include Mongoid::Document


  # ID	Action
  # 0	RSVP with no subs
  # 1	Invited
  # 2	Subscribed
  # 3	Refused
  # 4	Unsubscribed
  # 5	Removed

  field :id
  field :action

end
