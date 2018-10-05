class BrandMediaFolder
  include Mongoid::Document
  include Mongoid::Timestamps
  # albums featured by the profile

  field :user_id
  field :media_folder_id

  belongs_to :user


  before_create do
    max = 999999999
    min = 100000000
    self.id = rand(max - min) + min
  end

  index({ user_id: 1 })
  index({ media_folder_id: 1 })

end
