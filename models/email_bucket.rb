class EmailBucket
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Search


  field :bucket

  field :username,            type: String
  field :email,               type: String
  field :firstName
  field :lastName

  field :last_location
  field :profile_location

end