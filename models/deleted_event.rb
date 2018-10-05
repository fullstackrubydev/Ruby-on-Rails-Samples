class DeletedEvent
  include Mongoid::Document
  include Mongoid::Timestamps

  field :dump
end
