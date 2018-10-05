class GroupSerializer < ActiveModel::Serializer

  attribute :id, key: :groupId
  attribute :Name, key: :name
  attribute :created_at, key: :createDate
  attribute :owner
  attribute :isReadOnly
  attribute :index
  attribute :isImport
  attribute :countMember
  attribute :countSelectedMember
  attribute :processingStatus

  def processingStatus
    nil
  end

  def countSelectedMember
    0
  end

  def countMember
    object.count_group_members
  end

  def isImport
    object.IsImport == 1
  end

  def index
    nil
  end

  def isReadOnly
    %w(Co-Workers Family Friends).include? object.Name
  end

  def owner
    object.user.id
  end

end
