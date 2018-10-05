class EventUviteThemeCategory
  include Mongoid::Document
  include Mongoid::Timestamps
  field :id
  field :name
  field :order
  field :parent_id
  field :is_featured
  field :hide

end
