class EventFlagOption
  # static table
  include Mongoid::Document
  include Mongoid::Timestamps

  field :id
  field :description

  belongs_to :report_content
end
