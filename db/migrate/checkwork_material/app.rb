require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require './models.rb'
require 'json'
require 'net/http'
require 'uri'

get '/' do
  erb :index
end

post '/location' do
  
  #緯度,経度取得
  data = JSON.parse(request.body.read)
  latitude = data['latitude']
  longitude = data['longitude']
  #latitudeが緯度、longitudeが経度

end
