class GroupMember
  include Mongoid::Document
  include Mongoid::Timestamps
  belongs_to :user, optional: true
  belongs_to :group
  field :user_id

  index({ group_id: 1 })
  index({ user_id: 1 })
end
