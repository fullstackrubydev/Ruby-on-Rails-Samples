class EventLocation
  include Mongoid::Document
  include Mongoid::Timestamps

  field :event_location_id
  field :event_id
  field :address
  field :location
  field :url
  field :passcode
  field :conf_call
  field :city
  field :state
  field :country
  field :zip_code,          default: ''
  field :latitude,          type: Float, default: 0.0
  field :longitude,         type: Float, default: 0.0

  #validates :location, length: { maximum: 60 }
  embedded_in :event

  before_create do
    max = 999999999
    min = 100000000
    self.id = rand(max - min) + min #rand(100000000..999999999)# 9 digits
  end

end
