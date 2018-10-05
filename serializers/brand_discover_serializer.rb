class BrandDiscoverSerializer < ActiveModel::Serializer

  def self.serializer_for(model, options)
    if object.user_privacy == nil
      object.create_privacy
    end
    super
  end

  attribute :username
  attribute :id, key: :profileID
  attribute :taxonomy
  attribute :fullname
  attribute :location
  attribute :distance
  attribute :followers
  attribute :backgroundUrl
  attribute :avatarUrl
  attribute :isBrand
  attribute :hashtag
  attribute :ConnectionType, key: :connectionType
  attribute :profileConnectionToViewer
  attribute :viewerConnectionToProfile

  def taxonomy
    nil
  end

  def profileConnectionToViewer
    if instance_options[:connection][1] == 'Contact' && instance_options[:is_discover]
      -1
    else
      instance_options[:connection][0]
    end
  end

  def viewerConnectionToProfile
    if instance_options[:connection][1] == 'Contact' && instance_options[:is_discover]
      -1
    else
      instance_options[:connection][2]
    end
  end

  def ConnectionType
    if instance_options[:connection][1] == 'Contact' && instance_options[:is_discover]
      'Nothing'
    else
      instance_options[:connection][1]
    end
  end

  def fullname
    is_con =  instance_options[:connection][0] == 1
    is_self = instance_options[:current_user].id == object.id
    is_flwr = [0,1,4].include?(instance_options[:connection][0])
    p = object.type == 1 ? object.user_privacy.BusinessName : object.user_privacy.fullName rescue 1
    {
      value: (is_self || p==1 || (p==4 && is_con)|| (p==3 && is_flwr)) ? object.get_fullname_or_business_name : '',
      privacy: (object.user_privacy.present?)? object.user_privacy.BusinessName : 1
    }
  end

  def location
    is_con =  instance_options[:connection][0] == 1
    is_self = instance_options[:current_user].id == object.id
    is_flwr = [0,1,4].include?(instance_options[:connection][0])
    p = object.user_privacy.location rescue 1
    loc = (is_self || [1,2].include?(p)  || (p==4 && is_con)|| (p==3 && is_flwr)) ? object.get_location : ''
    {
        value: loc,
        privacy: (object.user_privacy.present?)? object.user_privacy.location : 1
    }
  end

  def distance
    instance_options[:distance]
  end

  def followers
    instance_options[:followers_count]
  end

  def backgroundUrl
    ''
    #"https://stg-cdn.unation.com/getResizedImage?URL=http://qa-cdn.unation.com/media/photos/2/22d7dd4b/i_22d7dd4b-9b4b-40cd-a6f2-3c6774a96c19.jpg"
  end

  def avatarUrl
    Rails.application.config.resize_cdn_url + object.get_avatar
  end
end
