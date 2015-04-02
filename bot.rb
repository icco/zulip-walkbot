require "rubygems"
require "bundler"
Bundler.require(:default, ENV["RACK_ENV"] || :development)

require "net/https"
require "open-uri"


# Zulip API Docs: https://zulip.com/api/endpoints/
# Forcast.io Docs: https://developer.forecast.io/docs/v2

configure do
  BOT_EMAIL_ADDRESS = ENV["BOT_EMAIL_ADDRESS"]
  BOT_API_KEY = ENV["BOT_API_KEY"]
  WEATHER_KEY = ENV["FORECASTIO_KEY"]
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
  get_most_recent_msgs(@queue_id, @last_msg_id).to_json
end

def get_most_recent_msgs queue_id, last_msg_id
  # curl -G https://api.zulip.com/v1/events \
  #  -u othello-bot@example.com:a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5 \
  #  -d "queue_id=1375801870:2942" \
  #  -d "last_event_id=-1"
  uri = URI("https://api.zulip.com/v1/events")
  Net::HTTP.start(
    uri.host,
    uri.port,
    :use_ssl => uri.scheme == "https"
  ) do |http|
    request = Net::HTTP::Get.new(uri.request_uri)
    request.set_form_data({
      "queue_id" => @queue_id,
      "last_event_id" => @last_msg_id,
    })
    request.basic_auth(BOT_EMAIL_ADDRESS, BOT_API_KEY)

    response = http.request(request)

    puts response
    body = JSON.parse(response.body)

    if body['result'].eql? 'success'
      return body['events']
    else
      p body
      return nil
    end
  end
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
    request.set_form_data({'event_types' => '["message"]'})
    request.basic_auth(BOT_EMAIL_ADDRESS, BOT_API_KEY)

    response = http.request(request)

    puts response
    body = JSON.parse(response.body)

    if body['result'].eql? 'success'
      return [body['queue_id'], body['last_event_id']]
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
