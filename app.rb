# app.rb
$: << File.join(settings.root, 'models')
p $:

require 'sinatra'
require 'slim'
require 'yaml'
require 'json'
require 'sinatra/reloader' if development?
require "facility"
require 'ostruct'

set :static_cache_control, [:public, max_age: 60 * 60 * 24 * 365]

DATA_DIR = File.join(settings.root, 'data')

class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end
end

def facilities
  @@facilities ||= begin
    path = File.join(DATA_DIR, 'facilities.yml')
    a = YAML.load(File.read(path))['facilities']
    JSON.parse(a.to_json, object_class: OpenStruct).map{|o| Facility.new(o) }
  end
end


get '/' do
  @facilities = facilities
  slim :index
end

def facility name, year=nil, month=nil
  d = Date.today
  @year = year || d.year
  @month = month || d.month
  beginning_of_month = Date.new(@year, @month, 1)
  @date = beginning_of_month
  @from_at = beginning_of_month - beginning_of_month.wday
  end_of_month = Date.new(@year + @month / 12, (@month % 12) + 1, 1) - 1
  @end_at = end_of_month + (7 - 1) - end_of_month.wday
  @facility = facilities.find{|f| f.name == name}
  slim :facilities
end

get '/facilities/:name/:year/:month' do
  facility params["name"], params["year"].to_i, params["month"].to_i
end

get '/facilities/:name' do
  facility params["name"]
end

get '/about' do
  slim :about
end


