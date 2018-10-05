class EventTheme
  include Mongoid::Document
  include Mongoid::Timestamps
  # include RandomNumberIdentifier

  field :event_id
  field :theme_url
  field :thumbnail_url
  field :theme_alignment
  field :theme_color
  field :theme_bg_color
  field :hide_text

  embedded_in :event

  before_create do
    max = 999999999
    min = 100000000
    self.id = rand(max - min) + min
  end

end
