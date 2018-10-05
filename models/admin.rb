class Admin

  include Mongoid::Document
  include Mongoid::Timestamps
  include RandomNumberIdentifier

  field :id

  field :email,            type: String
  field :lt_token,          type: String
  field :super_admin,       type: Boolean, default: false

  belongs_to :user
  has_many :av_users

  before_create do
    max = 999999999
    min = 100000000
    self.id = rand(max - min) + min
  end

  index({ email: 1 }, { unique: true })

end
