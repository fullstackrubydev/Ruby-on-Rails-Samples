class Connection

  include Mongoid::Document
  include Mongoid::Timestamps
  # region Fields
 # increments :id, seed: 8934592

  field :connection_type, default: 0
    # 0 - one way connection
    # 1 - two way connection

  # rest of the fields are not used
  # field :IsBlockUser
  # field :IsBlockNotifications
  # field :IsBlockQuickVites
  # field :IsBlockUnotes
  # endregion

  before_create do
    max = 999999999
    min = 100000000
    self.id = rand(max - min) + min
  end

  belongs_to :follower, class_name: 'User', inverse_of: :active_connections
  belongs_to :followed, class_name: 'User', inverse_of: :passive_connections

  index({ follower_id: 1 })
  index({ followed_id: 1 })
  #index({ connection_type: 1 })

end
