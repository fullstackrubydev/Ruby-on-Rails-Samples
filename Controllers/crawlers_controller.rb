class CrawlersController < ActionController::Base

  require 'fastimage'

  def event_details
    Rails.logger.info("USERAGENT: #{request.headers['HTTP_USER_AGENT']}")
    event = Event.find_by(id: params[:event_id].to_i)
    if event.present?
      @title = event.name
      @description = event.description.blank? ? "#{event.user.username}'s event" : event.description
      @theme_url = event.get_theme
      @redirect_url=  "#{Rails.application.config.event_share_base + event.id.to_s}"
      size = FastImage.size(@theme_url.to_s) rescue nil
      @width = size.blank? ? '600' : size[0].to_s
      @height = size.blank? ? '315' : size[1].to_s
    end
  end
end