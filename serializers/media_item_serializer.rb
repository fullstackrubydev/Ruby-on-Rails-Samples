class MediaItemSerializer < ActiveModel::Serializer
  attribute :Title, key: :title
  attribute :Description, key: :description
  attribute :contentURL
  attribute :thumbURL
  attribute :message
  attribute :id
  attribute :fileID
  attribute :size

  def contentURL
    object.get_image
  end

  def thumbURL
    object.get_image_thumb
  end

  def message
    ''
  end

  def id
    object.id
  end

  def fileID
    object.image_file_name
  end

  def size
    object.image_file_size
  end

end
