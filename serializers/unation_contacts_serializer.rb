class UnationContactsSerializer < ActiveModel::Serializer

  attribute :username
  attribute :id, key: :profileID
  attribute :fullname
  attribute :location
  attribute :followers
  attribute :backgroundUrl
  attribute :avatarUrl

  def fullname
    is_self = instance_options[:current_user].id == object.id
    is_con =  instance_options[:connection][0] == 1
    is_flwr = [0,1,4].include?(instance_options[:connection][0])
    p = object.type == 1 ? object.user_privacy.BusinessName : object.user_privacy.fullName rescue 1
    {
      value: (is_self || p == 1 || (p==4 && is_con)|| (p==3 && is_flwr)) ? object.get_fullname_or_business_name : '',
      privacy: (object.user_privacy.present?)? object.user_privacy.BusinessName : 1
    }
  end

  def location
    is_self = instance_options[:current_user].id == object.id
    is_con =  instance_options[:connection][0] == 1
    is_flwr = [0,1,4].include?(instance_options[:connection][0])
    p = object.user_privacy.location rescue 1

    loc = (is_self || p == 1  || (p==4 && is_con)|| (p==3 && is_flwr)) ? object.get_location : ''
    {
      value: loc,
      privacy: p
    }
  end

  def followers
    object.count_followers
  end

  def backgroundUrl
    "https://stg-cdn.unation.com/getResizedImage?URL=http://qa-cdn.unation.com/media/photos/2/22d7dd4b/i_22d7dd4b-9b4b-40cd-a6f2-3c6774a96c19.jpg"
  end

  def avatarUrl
    av =  object.get_avatar
    if av.present?
      Rails.application.config.resize_cdn_url + av
    else
      ''
    end
  end
end
