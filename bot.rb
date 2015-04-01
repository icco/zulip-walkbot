require 'sinatra'

# Zulip API Docs: https://zulip.com/api/endpoints/

configure do
  BOT_EMAIL_ADDRESS = ENV['BOT_EMAIL_ADDRESS']
  BOT_API_KEY = ENV['BOT_API_KEY']
  WEATHER_KEY = ENV['FORECASTIO_KEY']
end

get '/' do
  erb :index
end
