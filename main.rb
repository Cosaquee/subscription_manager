require 'json'
require 'sinatra/base'
require 'sinatra/cors'
require 'google/cloud/firestore'
require 'securerandom'
require 'date'

class Api < Sinatra::Base
  register Sinatra::Cors

  set :allow_origin, "http://localhost:8080"
  set :allow_methods, "*"
  set :allow_headers, "content-type,if-modified-since"
  set :expose_headers, "location,link"

  def initialize
    super
  end

  get '/subscriptions/name/:name' do |name|
    firestore = Google::Cloud::Firestore.new

    subscriptions = firestore.col "Subscriptions"

    query = subscriptions.where "name", "=", "#{name}"

    responses = []
    query.get do |sub|
      responses.append(sub.data)
    end

    {data: responses}.to_json
  end

  get '/subscriptions/payment_type/:type' do |type|
    firestore = Google::Cloud::Firestore.new

    subscriptions = firestore.col "Subscriptions"

    query = subscriptions.where "type", "=", "#{type}"

    responses = []
    query.get do |sub|
      responses.append(sub.data)
    end

    {data: responses}.to_json
  end

  post '/subscriptions' do
    @name = params[:name]
    @amount = params[:amount]
    @payment_done = false
    @payment_date = params[:payment_date]
    @payment_type = params[:payment_type]
    @payment_next = params[:paymanet_next]

    firestore = Google::Cloud::Firestore.new

    subscriptions = firestore.col "Subscriptions"

    data = {
      name: @name,
      amount: @amount,
      payment_type: @paymanet_type,
      payment_next: @payment_date + 30, # For now assume that we have 1 month subscription
      payment_done: @payment_done,
      payment_date: @payment_date
    }

    subscriptions.add data
  end
end
