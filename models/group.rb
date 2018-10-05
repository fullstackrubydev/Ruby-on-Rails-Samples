class Group
  #require 'autoinc'
  include Mongoid::Document
  include Mongoid::Timestamps
  include RandomNumberIdentifier

  field :Name
  field :IsImport,            default: 0

  field :isPopulated,         default: false
  field :job_id
  # field :IsReadOnly
  # field :Index

  belongs_to :user
  has_many :group_members

  index({ user_id: 1 })
  index({ Name: 1 })

  before_create do
    max = 999999999
    min = 100000000
    self.id = rand(max - min) + min
  end

  def count_group_members
    User.without(:event_guest_lists,:user_privacy,:user_interests).
      in(id: group_members.pluck(:user_id).uniq & self.user.all_connections(true) ).
      where(:user_deleted.ne => 1).
      count
  end

  def add_member(user)
    group_members.create(user_id: user.id)
  end

  def add_members(user_ids)
    user_ids = user_ids.uniq
    user_ids.each do |id|
      group_members.create(user_id: id)
    end
  end
end
