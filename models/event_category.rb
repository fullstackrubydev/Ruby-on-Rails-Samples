class EventCategory
  include Mongoid::Document
  include Mongoid::Timestamps

  field :CategoryID, as: :category_id
  field :sub_category_id # found in taxonomy
  # 1	4294968092	4294967331	4294967606
  # 2	4294968112	4294967331	4294967606
  # 3	4294968137	4294967331	4294967606
  has_one :taxonomy
  embedded_in :event

  before_create do
    max = 999999999
    min = 100000000
    self.id = rand(max - min) + min
  end
end
