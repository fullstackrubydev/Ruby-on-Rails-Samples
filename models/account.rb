class Account

  include Mongoid::Document
  include Mongoid::Timestamps
  include RandomNumberIdentifier


  field :invitation_date,        type: Time
  field :inv_acception_date,      type: Time
  field :invitation_expiry_date,        type: Time
  field :email,                 type: String
  field :total_events,        type: Integer, default: 0
  field :total_revenue,          type: Float, default: 0.00

  # validates_uniqueness_of :user_id, :scope => :av_user_id

  belongs_to :user, optional: true
  belongs_to :av_user
  belongs_to :user_status

  before_create do
    max = 999999999
    min = 100000000
    self.id = rand(max - min) + min
  end

end
