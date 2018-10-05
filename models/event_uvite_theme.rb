class EventUviteTheme
  include Mongoid::Document
  include Mongoid::Timestamps
  field :_id,                    as: :theme_id
  field :Name
  field :ThumbnailURL
  field :ThemeURL
  #field :TextCSS
  field :UviteThemeCategoryID
  field :user_id, default: nil

  has_many :events,   primary_key: :theme_id,   foreign_key: :theme_id

  #field :Order
  #field :TaxonomyId
  #field :TaxonomyParentId
  #field :FeaturedIndex

  def get_image
    Rails.application.config.cdn_url + ((self.ThemeURL[0] == '/') ? self.ThemeURL : "/#{self.ThemeURL}")
  end

  def get_image_thumb
    Rails.application.config.cdn_url + ((self.ThumbnailURL[0] == '/') ? self.ThumbnailURL : "/#{self.ThumbnailURL}")
  end

end
