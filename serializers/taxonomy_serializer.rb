class TaxonomySerializer < ActiveModel::Serializer
  attributes :id, :parent_id, :name, :image_url

  def image_url
    Rails.application.config.cdn_url + object.image_url.to_s
  end
  
end
