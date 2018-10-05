class EventCallToAction
  include Mongoid::Document

  # 1	Get Tickets
  # 2	Register Now

  field :id
  field :action_title, type: String


end
