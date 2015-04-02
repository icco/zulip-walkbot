require "rubygems"
require "bundler"
Bundler.require(:default, ENV["RACK_ENV"] || :development)

require "net/https"
require "open-uri"


# Zulip API Docs: https://zulip.com/api/endpoints/
# Forcast.io Docs: https://developer.forecast.io/docs/v2

def subscribe_all
  return subscribe(get_streams)
end

def subscribe streams
  streams.map! {|s| {name: s} }

  uri = URI("https://api.zulip.com/v1/users/me/subscriptions")
  Net::HTTP.start(
    uri.host,
    uri.port,
    :use_ssl => uri.scheme == "https"
  ) do |http|
    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data({subscriptions: streams.to_json})
    request.basic_auth(BOT_EMAIL_ADDRESS, BOT_API_KEY)

    response = http.request(request)
    body = JSON.parse(response.body)

    if body["result"].eql? "success"
      return true
    else
      p body
    end
  end

  return false
end

def get_streams
  uri = URI("https://api.zulip.com/v1/streams")
  Net::HTTP.start(
    uri.host,
    uri.port,
    :use_ssl => uri.scheme == "https"
  ) do |http|
    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth(BOT_EMAIL_ADDRESS, BOT_API_KEY)

    response = http.request(request)
    body = JSON.parse(response.body)

    if body["result"].eql? "success"
      ev = body["streams"]
      return ev.map {|s| s["name"] }
    else
      p body
    end
  end

  return []
end

def get_most_recent_msgs queue_id, last_msg_id
  # curl -G https://api.zulip.com/v1/events \
  #  -u othello-bot@example.com:a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5 \
  #  -d "queue_id=1375801870:2942" \
  #  -d "last_event_id=-1"
  uri = URI("https://api.zulip.com/v1/events")
  params = {
    "queue_id" => queue_id,
    "last_event_id" => last_msg_id,
    "dont_block" => true,
  }
  uri.query = URI.encode_www_form(params)
  Net::HTTP.start(
    uri.host,
    uri.port,
    :use_ssl => uri.scheme == "https"
  ) do |http|
    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth(BOT_EMAIL_ADDRESS, BOT_API_KEY)

    response = http.request(request)
    body = JSON.parse(response.body)
    puts "Polled #{uri.to_s} with #{params.inspect}."

    if body["result"].eql? "success"
      p body
      ev = body["events"]
      puts "Got #{ev.count} results."
      return ev
    else
      p body
    end
  end

  return nil
end

def weather
  # Recurse Center Location:
  # http://www.latlong.net/ translation of 455 Broadway New York, NY 10013
  lat = "40.720780"
  long = "-74.001119"
  forecast_url = "https://api.forecast.io/forecast/#{WEATHER_KEY}/#{lat},#{long}"
  return JSON.parse(open(forecast_url).read)
end

def register
  uri = URI("https://api.zulip.com/v1/register")

  Net::HTTP.start(
    uri.host,
    uri.port,
    :use_ssl => uri.scheme == "https"
  ) do |http|
    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data({})
    request.basic_auth(BOT_EMAIL_ADDRESS, BOT_API_KEY)

    response = http.request(request)
    body = JSON.parse(response.body)

    if body["result"].eql? "success"
      id = [body["max_message_id"], body["last_event_id"]].max
      return [body["queue_id"], id]
    else
      p body
    end
  end

  return nil
end

def ftoc f
  return (((f - 32) * 5) / 9)
end

def format_weather weather_blob
  current = weather_blob["currently"]
  # Long strings are long.
  return "Currently %s and %0.1f&deg;F / %.1f&deg;C. It will be %s" % [
    current["summary"],
    current["apparentTemperature"].to_f,
    ftoc(current["apparentTemperature"].to_f),
    weather_blob["minutely"]["summary"].downcase,
  ]
end

configure do
  BOT_EMAIL_ADDRESS = ENV["BOT_EMAIL_ADDRESS"]
  BOT_API_KEY = ENV["BOT_API_KEY"]
  WEATHER_KEY = ENV["FORECASTIO_KEY"]

  subscribe_all
  @queue_id, @last_msg_id = register
end

get "/" do
  erb :index
end

get "/weather.json" do
  content_type :json
  weather.to_json
end

get "/poll" do
  @queue_id, @last_msg_id = register if @queue_id.nil?

  content_type :json
  get_most_recent_msgs(@queue_id, @last_msg_id - 10).to_json
end

after do
  $stdout.flush
end
