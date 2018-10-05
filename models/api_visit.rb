class ApiVisit
  include Mongoid::Document

  field :ip
  field :port
  field :user_agent
  field :end_point
  field :ip_location
  field :query_string
  field :user_id
  field :ratio
  field :lat
  field :lng
  field :time#, type: Time

  index({ time: 1 })

  #request.headers['REMOTE_ADDR'] # ip
  #request.headers['REMOTE_PORT']
  #request.headers['HTTP_USER_AGENT']
  #request.headers['PATH_INFO']
  #params[:ratio].to_i
  #params[:latitude].to_f.round(4)
  #params[:longitude].to_f.round(4)
  #request.headers['QUERY_STRING']

  # after_initialize do
  #   self.time = Time.parse(self.time.to_s)
  # end
  #
  # before_save do
  #   self.time = Time.parse(self.time.to_s)
  # end
  #
  # before_create do
  #   self.time = Time.parse(self.time.to_s)
  # end

end