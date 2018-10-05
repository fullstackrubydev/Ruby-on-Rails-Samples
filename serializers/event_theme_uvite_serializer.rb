class EventThemeUviteSerializer < ActiveModel::Serializer
  attributes :id

  attribute :id         #": 6873,
  attribute :Name, key: :name         #": "B7e.jpg",
  attribute :css          #": "etHide #FFFFFF",
  attribute :background         #": "#FFFFFF",
  attribute :position         #": "etHide",
  attribute :thumbnail          #": "http://qa-cdn.unation.com/media/themes/f/f315909e/t_f315909e-ba9d-421f-885c-989f7168921c.jpg",
  attribute :url          #": "http://qa-cdn.unation.com/media/themes/f/f315909e/i_f315909e-ba9d-421f-885c-989f7168921c.jpg",
  attribute :color          #": "#000000",
  attribute :taxonomyID         #": null,
  attribute :taxonomyParentId         #": null,
  attribute :user_id, key: :userID
  attribute :type         #": 0

  def type
    0
  end

  def taxonomyParentId
    nil
  end

  def taxonomyID
    nil
  end

  def color
    '#000000'
  end

  def url
    Rails.application.config.resize_cdn_url + object.get_image
  end

  def thumbnail
    Rails.application.config.resize_cdn_url + object.get_image_thumb
  end

  def position
    "etHide"
  end

  def background
    '#FFFFFF'
  end

  def css
    'etHide #FFFFFF'
  end
end
