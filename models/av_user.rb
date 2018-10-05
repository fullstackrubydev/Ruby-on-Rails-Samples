class AvUser
  #require 'autoinc'
  include Mongoid::Document
  include Mongoid::Timestamps
  include RandomNumberIdentifier


  # region Constants
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  #increments :id, seed: 5634592

  field :username,              type: String
  field :business_name,         type: String
  field :fname,                 type: String
  field :lname,                 type: String
  field :zip_code,              type: String
  field :invitation_date,       type: Time
  field :inv_acception_date,    type: Time
  field :email,                 type: String
  field :has_stripe_linked,     type: Boolean,  default: false
  field :first_event_share,     type: Float,    default: 20.00
  field :remaining_event_share, type: Float,    default: 10.00
  field :type,                  type: Integer,  default: 1
  field :total_accounts,        type: Integer,  default: 0
  field :total_earned,          type: Float,    default: 0.00
  field :contractSigned,        type: Boolean,  default: false

  field :lt_token, type: String, default: '1234qwerasdf'

  # from profile table
  field :bio
  field :gender
  field :high_school
  field :college
  field :occupation
  field :phone
  field :website
  field :address
  field :city
  field :state
  field :latitude
  field :longitude
  field :hashtag

  # region Validations
  validates :username,      presence: true, unless: proc { self.type == 2}, # 2 is for non user
            uniqueness: { case_sensitive: false }
  validates :email,         presence: true, length: { maximum: 255 },
            format: { with: VALID_EMAIL_REGEX }, uniqueness: { case_sensitive: false }
  validates :type,          presence: true

  belongs_to :user
  belongs_to :admin
  has_many :accounts
  belongs_to :user_status

  before_create do
    max = 999999999
    min = 100000000
    self.id = rand(max - min) + min
  end

  def is_new
    invitation_date > Rails.application.config.contract_feature_date.to_datetime
  end

  def showContract
    result = {}
    if (is_new && !contractSigned && user_status_id == 2) || (!is_new && !contractSigned && user_status_id == 2)
      result[:position] = 'everywhere'
      result[:permission] = true
    elsif (is_new && contractSigned && user_status_id == 3) || (!is_new && contractSigned && user_status_id == 3)
      result[:position] = 'setting only'
      result[:permission] = true
    elsif !contractSigned && user_status_id == 3
      result[:position] = 'none'
      result[:permission] = false
    end
    result
  end

end
