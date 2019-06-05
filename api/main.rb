require 'json'
require 'sinatra/base'
require 'sinatra/cors'
require 'google/cloud/firestore'
require 'securerandom'
require 'date'
require 'scrypt'
require 'jwt'

# require 'pry'

class JwtAuth
  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      options = { algorithm: 'HS256', iss: ENV['JWT_ISSUER'] }
      bearer = env.fetch('HTTP_AUTHORIZATION', '').slice(7..-1)
      payload, header = JWT.decode bearer, ENV['JWT_SECRET'], true, options

      env[:scopes] = payload['scopes']
      env[:user] = payload['user']
      env[:sub] = payload['sub']

      @app.call env
    rescue JWT::DecodeError
      [401, { 'Content-Type' => 'text/plain' }, ['A token must be passed.']]
    rescue JWT::ExpiredSignature
      [403, { 'Content-Type' => 'text/plain' }, ['The token has expired.']]
    rescue JWT::InvalidIssuerError
      [403, { 'Content-Type' => 'text/plain' }, ['The token does not have a valid issuer.']]
    rescue JWT::InvalidIatError
      [403, { 'Content-Type' => 'text/plain' }, ['The token does not have a valid "issued at" time.']]
    end
  end
end

class Api < Sinatra::Base
  use JwtAuth
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
    process_request(request, 'add_subscription') do |req, username|
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
        payment_next: DateTime.strptime(@payment_date, "%s") + 30, # For now assume that we have 1 month subscription
        payment_done: @payment_done,
        payment_date: @payment_date
      }

      subscriptions.add data
    end
  end

  def process_request req, scope
    scopes, user, user_id = req.env.values_at :scopes, :user, :sub
    username = user['username'].to_sym

    firestore = Google::Cloud::Firestore.new

    users = firestore.col "subscriptions-users"
    query = users.where("name", "=", "#{username}")

    responses = []
    query.get do |sub|
      responses.append(sub.data)
    end

    user = responses[0]

    if scopes.include?(scope) && user
      yield req, username
    else
      halt 403
    end
  end
end

class Public < Sinatra::Base
  register Sinatra::Cors

  set :allow_origin, "http://localhost:8080"
  set :allow_methods, "*"
  set :allow_headers, "content-type,if-modified-since"
  set :expose_headers, "location,link"

  def initialize
    super
  end

  post "/login" do
    username = params[:username]
    password = params[:password]

    firestore = Google::Cloud::Firestore.new

    users = firestore.col "subscriptions-users"
    query = users.where("name", "=", "#{username}")

    responses = []
    query.get do |sub|
      responses.append(sub.data)
    end

    user = responses[0]

    p = SCrypt::Password.new(user[:password_hash])

    if (p == password)
      content_type :json
      { token: token(username, user[:id]) }.to_json
    else
      puts 'Here'
      halt 401
    end
  end

  def token(username, id)
    JWT.encode payload(username, id), ENV['JWT_SECRET'], 'HS256'
  end

  def payload(username, id)
    {
      exp: Time.now.to_i + 60 * 60,
      iat: Time.now.to_i,
      sub: id,
      iss: ENV['JWT_ISSUER'],
      scopes: ['add_subscription', 'list_subscription'],
      user: {
        username: username
      }
    }
  end
end
