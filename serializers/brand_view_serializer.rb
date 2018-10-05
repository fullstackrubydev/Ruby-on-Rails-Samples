class BrandViewSerializer < ActiveModel::Serializer

  has_many :featured_events, serializer: FeaturedEventSerializer, key: :events
  attribute :photoItems
  attribute :videoItems
  attribute :photoAlbums
  attribute :videoAlbums
  attribute :about

  attribute :publicEventsCount
  attribute :photosCount
  attribute :username
  attribute :fullname
  attribute :hashtag
  attribute :followers_count, key: :followers
  attribute :following_count, key: :following
  attribute :backgroundUrl
  #attribute :mediaBrandPhotoFolderID
  attribute :profileConnectionToViewer
  attribute :viewerConnectionToProfile
  attribute :isBrand
  attribute :events


  def photosCount
    # actually featured album count
    object.count_featured_media_items
  end
  def following_count
    object.count_following
  end
  def followers_count
    object.count_followers
  end
  def publicEventsCount
    is_self = instance_options[:current_user].id == object.id
    object.count_public_events(is_self)
  end
  def videoAlbums
    nil
  end

  def photoAlbums
    ids = object.brand_media_folders.pluck(:media_folder_id)
    albums_all = MediaFolder.includes(:event).in(id: ids)
    albums_public = []
    albums_all.map {|x|
      if ((x.Type == 'B' || (x.event.type == 'PU' && x.event.status != 3) ) rescue false)
        albums_public.push(x)
      end
    }
    {
      media: albums_public.map{|album| MediaFolderSerializer.new(album, options ={user: object})}
    }
  end

  def videoItems
    nil
  end

  def photoItems
    ids = object.brand_media_items.pluck(:media_item_id)
    photos_all = MediaItem.includes(:media_folder).in(id: ids)
    photos_public = []
    photos_all.map{ |x|
      if (( x.media_folder.Type == 'B' || (x.media_folder.event.type == 'PU' && x.media_folder.event.status != 3)) rescue false) # necessary parentheses
        photos_public.push(x)
      end
    }
    {
      media: photos_public.map{|photo| EventMediaPhotoSerializer.new(photo)},
      cursor: nil
    }
  end

  def profileConnectionToViewer
    instance_options[:connection][0]
  end

  def viewerConnectionToProfile
    instance_options[:connection][2]
  end

  def about
    if object.user_privacy == nil
      object.create_privacy
    end
    is_self = instance_options[:current_user].id == object.id
    is_con =  instance_options[:connection][0] == 1
    is_flwr = [0,1,4].include?(instance_options[:connection][0])
    {
      highSchool:     {value: object.highSchool,  privacy: object.user_privacy.highSchool},
      college:        {value: object.college,     privacy: object.user_privacy.college},
      occupation:     {value: object.occupation,  privacy: object.user_privacy.professionalAbout},
      profileType:    object.type,
      pendingEmail:   {value: (object.status == 7 && (is_self || [1,2].include?(object.user_privacy.email) ) ) ?
                                object.pending_email : nil, privacy: object.user_privacy.email},
      birthDate:      {value: ( ( is_self || [1,2].include?(object.user_privacy.birthDate)    || (object.user_privacy.birthDate== 4 && is_con)      || (object.user_privacy.birthDate== 3 && is_flwr)) && object.dateOfBirth.present? ) ?
                        object.dateOfBirth.strftime('%Y-%m-%dT%H:%M:%S') :
                        nil,
                       privacy: object.user_privacy.birthDate },
      avatar:         Rails.application.config.resize_cdn_url + object.get_avatar,
      bio:            {value: (is_self || [1,2].include?(object.user_privacy.personalAbout )  || (object.user_privacy.personalAbout == 4 && is_con) || (object.user_privacy.personalAbout == 3 && is_flwr)) ? object.get_bio : nil,         privacy: object.user_privacy.personalAbout },

      gender:         {value: (is_self || [1,2].include?(object.user_privacy.gender)          || (object.user_privacy.gender== 4 && is_con)         ||  (object.user_privacy.gender== 3 && is_flwr))   ? object.gender : nil,      privacy: object.user_privacy.gender},
      phone:          {value: (is_self || [1,2].include?(object.user_privacy.phone)           || (object.user_privacy.phone== 4 && is_con)          || (object.user_privacy.phone== 3 && is_flwr))    ? object.phone: nil,       privacy: object.user_privacy.phone},
      website:        {value: (is_self || [1,2].include?(object.user_privacy.website)         || (object.user_privacy.website== 4 && is_con)        || (object.user_privacy.website== 3 && is_flwr))  ? object.website : nil,     privacy: object.user_privacy.website},
      address:        {value: (is_self || [1,2].include?(object.user_privacy.location)        || (object.user_privacy.location== 4 && is_con)       || (object.user_privacy.location== 3 && is_flwr)) ? object.address : nil,     privacy: object.user_privacy.location},
      city:           {value: (is_self || [1,2].include?(object.user_privacy.location)        || (object.user_privacy.location== 4 && is_con)       || (object.user_privacy.location== 3 && is_flwr)) ? object.city: nil,        privacy: object.user_privacy.location},
      state:          {value: (is_self || [1,2].include?(object.user_privacy.location)        || (object.user_privacy.location== 4 && is_con)       || (object.user_privacy.location== 3 && is_flwr)) ? object.state: nil,       privacy: object.user_privacy.location},
      email:          {value: (is_self || [1,2].include?(object.user_privacy.email)           || (object.user_privacy.email== 4 && is_con)          || (object.user_privacy.email== 3 && is_flwr)) ? object.email : '' ,       privacy: object.user_privacy.email},

      location:       {value: (is_self || [1,2].include?(object.user_privacy.location)        || (object.user_privacy.location== 4 && is_con)       || (object.user_privacy.location== 3 && is_flwr)) ? {latitude: object.latitude.to_f, longitude: object.longitude.to_f} : {latitude: 0.0, longitude: 0.0},
                       privacy: object.user_privacy.location},

      fullname:       {value: (is_self || [1,2].include?(object.user_privacy.BusinessName )   || (object.user_privacy.BusinessName == 4 && is_con)  || (object.user_privacy.BusinessName == 3 && is_flwr)) ? object.get_fullname_or_business_name : '', privacy: object.user_privacy.BusinessName},
      name:           {value:  (is_self ||[1,2].include?(object.user_privacy.fullName)        || (object.user_privacy.fullName== 4 && is_con)       || (object.user_privacy.fullName== 3 && is_flwr)) ? {firstName: object.firstName.to_s, lastName: object.lastName.to_s} : {firstName: '', lastName: ''},
                       privacy: object.user_privacy.fullName}
    }
  end

  def backgroundUrl
    ''
  end

  def fullname
    is_con =  instance_options[:connection][0] == 1
    is_flwr = [0,1,4].include?(instance_options[:connection][0])
    is_self = instance_options[:current_user].id == object.id
    (is_self || [1,2].include?(object.user_privacy.BusinessName) || (object.user_privacy.BusinessName== 4 && is_con) || (object.user_privacy.BusinessName== 3 && is_flwr)) ? object.get_fullname_or_business_name : ''
  end
end
