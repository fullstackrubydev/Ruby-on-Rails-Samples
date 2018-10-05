class BrandSerializer < ActiveModel::Serializer

  attribute :name
  attribute :fullname
  attribute :location
  attribute :state
  attribute :city
  attribute :address
  attribute :website
  attribute :phone
  attribute :occupation
  attribute :college
  attribute :highSchool
  attribute :gender
  attribute :avatar
  attribute :bio
  attribute :type,          key: :profileType
  attribute :dateOfBirth,   key: :birthdate

  def fullname
    is_con =  instance_options[:connection][0] == 1
    is_self = instance_options[:current_user].id == object.id
    is_flwr = instance_options[:connection][0] == 1
    p = (object.type == 1 ? object.user_privacy.BusinessName : object.user_privacy.fullName) rescue 1
    (is_self || [1,2].include?(p ) || (p==4 && is_con)|| (p==3 && is_flwr)) ? object.get_fullname_or_business_name : ''
  end
  def name
    is_con =  instance_options[:connection][0] == 1
    is_flwr = [0,1,4].include?(instance_options[:connection][0])
    p = object.user_privacy.fullName rescue 1
    is_self = instance_options[:current_user].id == object.id
    if is_self || [1,2].include?(p ) || (p==4 && is_con)|| (p==3 && is_flwr)
      {
        firstName: object.firstName.to_s,
        lastName: object.lastName.to_s
      }
    else
      {
        firstName: '',
        lastName: ''
      }
    end
  end
  def location
    p = object.user_privacy.location rescue 1
    is_self = instance_options[:current_user].id == object.id
    is_con =  instance_options[:connection][0] == 1
    if is_self || [1,2].include?(p ) || (p==4 && is_con)|| (p==3 && is_flwr)
      {
        latitude: object.latitude.to_f,
        longitude: object.longitude.to_f
      }
    else
      {
        latitude: 0.0,
        longitude: 0.0
      }
    end
  end
  def avatar
    Rails.application.config.resize_cdn_url + object.get_avatar
  end

end
