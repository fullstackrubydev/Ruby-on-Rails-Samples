# For Public Actions; No authorization required; independent from application controller
class MiscController < ActionController::API
  require 'dragonfly'
  require 'csv'
  require 'spreadsheet'
  before_action :sanitize_params, except: [:report_visit, :get_pdf]
  before_action :toggle_report, only: [:report_visit]

  # All public urls

  def download_users_buckets_sheets
    params[:date] = params[:date].to_date rescue nil
    if params[:date].present? && params[:date] <= Date.today
      book = Spreadsheet::Workbook.new "users_buckets_#{params[:date]}"
      %w(tampa orlando miami keywest all).each do | location |
        email_buckets = EmailBucket.where(bucket: location)
        sheet = book.create_worksheet name: location
        format = Spreadsheet::Format.new :weight => :bold,
                                         :size => 10
        sheet.row(0).concat %w{Username Email FirstName LastName LastLocation CurrentLocation}
        sheet.row(0).default_format = format
        sheet.column(0).width = 30
        sheet.column(1).width = 60
        sheet.column(2).width = 20
        sheet.column(3).width = 20
        sheet.column(4).width = 20
        sheet.column(5).width = 20
        email_buckets.each_with_index do | record, index |
          sheet.row(index+2).concat [record.username, record.email, record.firstName, record.lastName, record.last_location, record.profile_location]
        end
      end
      book.write Rails.root.join("tmp", "users_buckets_#{Date.today.strftime("%e_%b_%Y").to_s.gsub(/\s+/, "")}.xls")
      send_file Rails.root.join("tmp", "users_buckets_#{Date.today.strftime("%e_%b_%Y").to_s.gsub(/\s+/, "")}.xls"), :filename => "users_buckets_#{params[:date]}.xls", :type =>  "application/vnd.ms-excel"
    end
  end

  def get_service
    render json:{}, status: :ok
  end
  def get_pdf
    file = File.open("#{Rails.root}/app/views/files/ambassador_contract.html")
    contents = file.read
    name = params[:name]
    pdf = WickedPdf.new.pdf_from_string(contents.gsub(/REPLACE_ME/, name.to_s), encoding: 'UTF-8')

    save_path = 'contract.pdf'
    File.open(save_path, 'wb') do |file|
      file << pdf
    end
    send_file(save_path, :type => 'application/pdf', filename: 'contract.pdf')
  end
  
  # If URL is invalid, return default image
  def get_resized_image
    if params[:url].present?
      random_string = SecureRandom.urlsafe_base64(32)
      begin
        if params[:width].present? && params[:height].present? && params[:width].to_i < 1280 && params[:height].to_i < 1280
          image = Dragonfly.app.fetch_url(params[:url]).thumb("#{params[:width]}x#{params[:height]}#")
        else
          image = Dragonfly.app.fetch_url(params[:url])
        end
        if image.image.present?
          ct = image.format
          expires_in(2.days, public: true)
          send_data(image, filename: random_string, type: "image/#{ct}", disposition: 'inline')
        else
          # This block does not execute mostly...
          image = Dragonfly.app.fetch_url(Rails.application.config.default_image)
          expires_in(1.week, public: true)
          send_data(image, filename: random_string, type: 'image/jpeg', disposition: 'inline')
        end
      rescue
        begin
          image = Dragonfly.app.fetch_url(Rails.application.config.default_image)
          expires_in(1.week, public: true)
          send_data(image, filename: random_string, type: 'image/jpeg', disposition: 'inline')
        rescue # in case cdn is down
          render json: ErrorResponse.new(
            code: 400,message: 'Invalid Image Url'
          ), adapter: :json, status: :bad_request
        end
      end
    else
      render json: ErrorResponse.new(
        code: 404,message: 'Image URL or dimensions not Found'
      ), adapter: :json, status: :not_found
    end
  end

  def get_base_64_image
    if params[:url].present?
      ret = Dragonfly.app.fetch_url(params[:url]).b64_data
      if ret.present?
        render json: {code: 200, message: nil, image: ret.split('base64,')[1]}, adapter: :json, status: :ok
      else
        render json: ErrorResponse.new( code: 422, message: 'Error encoding image'),
               adapter: :json, status: :unprocessable_entity
      end
    else
      render json: ErrorResponse.new( code: 404, message: 'Image URL not Found'),
             adapter: :json, status: :not_found
    end
  end

  def download_sample_csv
    send_file(
      "#{Rails.root}/app/views/files/sample.csv",
      type: "text/csv"
    )
  end

  def get_app_config
    node = {
      config: {
        callToActions: [
          {
              callToActionID: 1,
              actionTitle: 'Get Tickets'
          },
          {
              callToActionID: 2,
              actionTitle: 'Register'
          }
        ]
      }
    }
    render json: node, adapter: :json, status: :ok
  end

  def update_client
    render json: ErrorResponse.new( code: 503, message: 'Please update the app'),
           adapter: :json, status: :service_unavailable
  end

  def get_canceled_event_ids
    events = Event.only(:id).where(status: 2).pluck(:id)
    render json: {canceled_event_ids: events}, adapter: :json, status: :ok
  end

  def get_deleted_event_ids
    events = Event.only(:id).where(status: 3).pluck(:id)
    render json: {deleted_event_ids: events}, adapter: :json, status: :ok
  end

  def toggle_report
    if params[:status].present?
      status = params[:status] == 'on'
      if status
        RedisService.set('report_switch', {status:'on'})
      else
        RedisService.set('report_switch', {status:'off'})
      end
      render json:{message: 'Status of Reports set to ' + (status ? 'on':'off')}, status: :ok
      return nil
    end
  end

  def report_visit
    # Rails.logger.info "in report_visit"
    client_id = request.headers['client-id']
    client_secret = request.headers['client-secret']
    token = request.headers['token']
    user_token = Token.find_by(access_token: token)
    user_id = user_token.user_id rescue '-'
    email = User.only(:email).find_by(id: user_id).email rescue '-'
    allowed_emails = ['shzaidi@westagilelabs.com']
    # Rails.logger.info email
    if (params[:secret] == '8Bu1a1DOvdrowz_fTL1E_SMi0jFk8UE1w4ohnxF0RXqI' || (allowed_emails.include? email) ) # && client_id == Rails.application.secrets.api_key && client_secret == Rails.application.secrets.api_secret
      page_limit = params[:csv].present? ? 500: 100
      page_num = params[:page].present? ? (params[:page].to_i) : 1
      page_num = 1 if page_num < 1
      # Rails.logger.info 'in if'
      if params[:start].present? && params[:end].present?
        start_time = Time.parse(params[:start])
        end_time   = Time.parse(params[:end])
        records = ApiVisit.where(:time.gte => start_time, :time.lte => end_time  ).order_by(id: 'desc')
      else
        records = ApiVisit.all.order_by(id: 'desc').paginate( page: page_num, per_page: page_limit)
      end
      users_h = User.only(:id, :email).where( :id.in => records.pluck(:user_id).uniq ).group_by{|x| x.id}
      headers = ['Ip', 'port', 'user_agent', 'end_point', 'city', 'country','ip_location', 'email' ,'lat' , 'lng', 'date', 'time']

      if params[:csv].present?
        send_csv(headers, records, users_h)
      else
        send_json(headers, records, users_h)
      end
    else
      # Rails.logger.info 'in else'
      render json:{}, status: :unauthorized
    end
    # Rails.logger.info 'outside '
  end



  #######
  private

  def send_csv(headers, records, users_h)
    csv_file_path = '/tmp/report_api visit.csv'
    CSV.open(csv_file_path, 'w') do |writer|
      writer << headers
      records.each do |u|
        email =  users_h[u.user_id].first.email rescue '-'
        q = Geocoder.search("#{u.lat},#{u.lng}").first
        city = q.city rescue ' - '
        country = q.country rescue ' - '
        date = Time.parse(u.time.to_s).to_datetime.inspect[0..-15].gsub(',','')
        time = (u.time.to_s)[11..19]

        writer << [u.ip, u.port, '"' + u.user_agent + '"', u.end_point, city, country, '"' + (u.ip_location.to_s ) + '"', email , u.lat, u.lng, date, time]
      end
    end
    send_file(
      "#{csv_file_path}",
      type: "text/csv"
    )
  end

  def send_json(headers, records, users_h)
    rows = []
    records.each do |u|
      email =  users_h[u.user_id].first.email rescue '-'
      q = Geocoder.search("#{u.lat},#{u.lng}").first
      city = q.city rescue ' - '
      country = q.country rescue ' - '
      date = Time.parse(u.time.to_s).to_datetime.inspect[0..-15]
      time = (u.time.to_s)[11..19]

      rows.push([ u.ip, u.port, u.user_agent, u.end_point, city, country, u.ip_location ,email , u.lat, u.lng, date,time])
    end

    render json: {headers: headers, records: rows}, status: :ok
  end

  def sanitize_params
    params.downcase_key
  end

end

class Hash
  def downcase_key
    keys.each do |k|
      store(k.downcase, Array === (v = delete(k)) ? v.map(&:downcase_key) : v)
    end
    self
  end
end
