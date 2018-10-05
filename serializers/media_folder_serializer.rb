class MediaFolderSerializer < ActiveModel::Serializer
  attribute :id
  attribute :name
  attribute :thumbURL
  attribute :type
  attribute :parentID
  attribute :userID
  attribute :numberOfItems
  attribute :privacy
  attribute :isFeatured
  attribute :userName
  attribute :profilePicture
  attribute :amountFavs


  def name
    object.get_name
  end
  def userName
    # u = instance_options[:user]
    # if u.present?
    #   u.username
    # else
      ''
    # end
    #object.event.user.username
  end

  def amountFavs
    0
  end

  def parentID
    object.id
  end

  def profilePicture
    # u = instance_options[:user]#User.find_by( id: object.user_id.to_i )
    # if u.present?
    #   u.get_avatar
    # else
      ''
    # end
    #object.event.user.get_avatar
  end

  def userID
    object.user_id
  end

  def type
    'Photo'
  end

  def isFeatured
    # f = BrandMediaFolder.where(media_folder_id: object.id).first
    # f.present?
    false
  end

  def privacy
    # if object.event.present?
    #   object.event.type == 'PU' ? 'Public' : 'OnlyMe'
    # else
      'Public'
    # end
  end

  def thumbURL
    if object.id != -1
      Rails.application.config.resize_cdn_url + object.album_image
    else
      object.Type
    end
  end

  def numberOfItems
    if object.id != -1
      object.media_items.count
    else
      object.user_id
    end
  end
end
