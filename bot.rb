require 'rubygems'
require 'bundler'
Bundler.require(:default, ENV['RACK_ENV'] || :development)
require 'net/http'

# Zulip API Docs: https://zulip.com/api/endpoints/
# Forcast.io Docs: https://developer.forecast.io/docs/v2

configure do
  BOT_EMAIL_ADDRESS = ENV['BOT_EMAIL_ADDRESS']
  BOT_API_KEY = ENV['BOT_API_KEY']
  WEATHER_KEY = ENV['FORECASTIO_KEY']
end

get '/' do
  erb :index
end

def weather
  # Recurse Center Location:
  # http://www.latlong.net/ translation of 455 Broadway New York, NY 10013
  lat = "40.720780"
  long = "-74.001119"
  forecast_url = "https://api.forecast.io/forecast/#{WEATHER_KEY}/#{lat},#{long}"

  # There are totally simpler ways of writing this, just felt like being verbose.
  url = URI.parse(forecast_url)
  req = Net::HTTP::Get.new(url.to_s)
  res = Net::HTTP.start(url.host, url.port) {|http| http.request(req) }
  res.body
end
