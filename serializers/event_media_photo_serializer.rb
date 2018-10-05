class EventMediaPhotoSerializer < ActiveModel::Serializer
  attribute :id
  attribute :userName
  attribute :profilePicture
  attribute :contentURL
  attribute :Description, key: :description
  attribute :fileID
  attribute :thumbURL
  attribute :Title, key: :title
  attribute :folderID
  attribute :type
  attribute :privacy
  attribute :created_at, key: :createdAt
  attribute :amountFavs
  attribute :isFeatured
  attribute :source

  def id
    object.id
  end

  def isFeatured
    #f = BrandMediaItem.where(mdeia_item_id: object.id )
    #f.present?
    false
  end

  def userName
    #object.media_folder.event.user.username
    # u = User.find_by( id: object.media_folder.user_id.to_i )
    # if u.present?
    #   u.username
    # else
      ''
    # end
  end

  def profilePicture
    #object.media_folder.event.user.get_avatar
    # u = User.find_by( id: object.media_folder.user_id.to_i )
    # if u.present?
    #   u.get_avatar
    # else
      ''
    # end
  end

  def contentURL
    Rails.application.config.resize_cdn_url + object.get_image
  end

  def thumbURL
    Rails.application.config.resize_cdn_url + object.get_image_thumb
  end

  def fileID
    object.image_file_name
  end

  def folderID
    object.media_folder.id rescue nil
  end

  def type
    'Photo'
  end

  def privacy
    # begin
    #   (object.media_folder.event.type == 'PU') ?
    #     'Public' : 'Private'
    # rescue
      'Private'
    # end

  end

  def amountFavs
    0
  end

  def source
    #
    # {
    #   type: 70,
    #   id: object.media_folder.id,
    #   name: object.media_folder.Name
    # }
    #
      nil
  end

end
