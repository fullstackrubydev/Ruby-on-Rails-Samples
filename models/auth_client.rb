class AuthClient
  include Mongoid::Document
  include Mongoid::Timestamps


  field :id
  field :client_id
  field :client_secret
  field :scope

  validates :client_id, presence: true
  validates :client_secret, presence: true
  validates :scope, presence: true

end
