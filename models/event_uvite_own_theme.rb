class EventUviteOwnTheme
  #require 'autoinc'
  include Mongoid::Document
  include Mongoid::Paperclip
  include RandomNumberIdentifier
  include Mongoid::Timestamps
  field :_id, as: :uvite_own_theme_id
  field :user_id
  field :Name
  field :ThumbnailURL
  field :ThemeURL
  #field :TextPositionCSS
  #field :TextBackgroundCSS
  #field :TextColorCSS
  has_mongoid_attached_file :image
  validates_attachment_content_type :image, content_type: %r(\Aimage/.*\z)

  has_mongoid_attached_file :image_thumb
  validates_attachment_content_type :image_thumb, content_type: %r(\Aimage/.*\z)

  has_many :events,   primary_key: :uvite_own_theme_id,   foreign_key: :uvite_own_theme_id

  belongs_to :user, counter_cache: :media_event_own_theme_count

  before_create do
    max = 999999999
    min = 100000000
    self.id = rand(max - min) + min
  end

  def get_image
    if image_file_name.present?
      'http:'+ self.image.url
    else
      Rails.application.config.cdn_url + ((self.ThemeURL[0] == '/') ? self.ThemeURL : "/#{self.ThemeURL}")
    end
  end

  def get_image_thumb
    if image_thumb_file_name.present?
      'http:'+ self.image_thumb.url
    else
      Rails.application.config.cdn_url + ((self.ThumbnailURL[0] == '/') ? self.ThumbnailURL : "/#{self.ThumbnailURL}")
    end
  end

end
