class AssociationToken
  #require 'autoinc'

  include Mongoid::Document
  include Mongoid::Timestamps

  #include Mongoid::Autoinc


  #increments :id, seed: 4434592

  field :admin_id
  field :account_id
  field :av_user_id
  field :user_id
  field :invitation_token
  field :email
  field :expire,      type: Time

  # region Events
  after_initialize :set_defaults

  #endregion

  # region Methods

  def set_defaults
    if self.expire.blank?
      self.expire = 7.days.from_now
    end
  end

  # endregion
end