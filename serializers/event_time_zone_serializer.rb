class EventTimeZoneSerializer < ActiveModel::Serializer
  attributes :name, :description, :abbreviation
end
