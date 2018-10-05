class Contact
  include Mongoid::Document
  include Mongoid::Timestamps
  field :Email, type: String
  field :ProfileID,                 as: :user_id
  field :ProfileConnectionID,       as: :contacted_id
  field :isconnection
  field :InvitationCode
  field :InvitationAccepted
  field :Deleted
  field :Hide
  field :FullName

  belongs_to :user

  index({ user_id: 1 })
  index({ contacted_id: 1 })

  before_create do
    max = 999999999
    min = 100000000
    self.id = rand(max - min) + min
  end

end
