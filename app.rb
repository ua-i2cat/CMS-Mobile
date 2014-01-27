require 'sinatra/base'
require 'rack/flash'
require 'data_mapper'
require 'warden'
require 'mustache/sinatra'


class CMS < Sinatra::Base
  # Storage config
  MULTIMEDIA_DIR = "#{Dir.pwd}/storage/multimedia"
  TMP_DIR = "#{Dir.pwd}/storage/tmp"

  # DataMapper configuration
  require_relative 'models/user'
  require_relative 'models/point'
  require_relative 'models/multimedia'

  DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/database.db")
  DataMapper.finalize

  Models::User.auto_upgrade!
  Models::Point.auto_upgrade!
  Models::Multimedia.auto_upgrade!

  # Warden configuration
  use Rack::Session::Cookie, :secret => "i2cheese"

  use Warden::Manager do |config|
    config.serialize_into_session { |user| user.id }
    config.serialize_from_session { |id| Models::User.get(id) }
    config.scope_defaults :default,
                          :strategies => [:password],
                          :action => 'unauthenticated'
    config.failure_app = self
  end

  Warden::Manager.before_failure do |env, opts|
    env['REQUEST_METHOD'] = 'POST'
  end

  Warden::Strategies.add(:password) do
    def valid?
      params['email'] && params['password']
    end

    def authenticate!
      user = Models::User.first(:email => params['email'])

      if user.nil?
        fail!("No hi ha cap usuari amb el correu electrònic introduït")
      elsif user.authenticate(params['password'])
        user.update(:last_login => Time.now)
        success!(user)
      else
        fail!("No s'ha pogut fet login")
      end
    end
  end

  # Rack::Flash configuration
  #enable :sessions
  use Rack::Flash, :accessorize => [:error, :success, :info]


  # Mustache configuration
  register Mustache::Sinatra

  require_relative 'views/layout'
  require_relative 'views/home'
  require_relative 'views/email'
  require_relative 'views/register'
  require_relative 'views/login'
  require_relative 'views/users'
  require_relative 'views/user_create'
  require_relative 'views/image_create'

  set :mustache, {
    :views => 'views',
    :templates => 'templates'
  }

  # Require workers
  require_relative 'workers/image_converter'

  before do
    @current_user = env['warden'].user || Models::Guest.new
    @flash = flash
  end

  get '/' do
    unless Models::User.has_admin?
      flash.info = "Aquest nou usuari serà l'administrador"
      redirect '/register'
    end
    mustache :home
  end

  get '/register' do
    if Models::User.has_admin?
      flash.error = "Ja existeix un usuari administrador. Demana-li accés"
      redirect '/'
    end
    mustache :register
  end

  post '/register' do
    if Models::User.has_admin?
      flash.error = "Ja existeix un usuari administrador. Demana-li accés"
      redirect '/'
    end

    name = params["name"]
    password = params["password"]
    password_confirm = params["password_confirm"]
    email = params["email"]
    unless Models::User.has_admin?
      admin = true
    end
    if password != password_confirm
      flash[:error] = "Les contrasenyes no coincideixen"
      redirect '/register'
    end
    success = Models::User.create(
      :name => name,
      :email => email,
      :password => password,
      :created_at => Time.now,
      :updated_at => Time.now,
      :admin => admin
    )
    unless success
      flash.error = "Hi ha hagut un problema amb el registre. Prova un altre cop"
      redirect '/register'
    else
      flash.success = "T'has registrat amb èxit. Ara ja pots entrar"
      redirect '/login'
    end
  end

  get '/user/create' do
    env['warden'].authenticate!
    unless @current_user.admin?
      flash.error = "Un usuari no administrador no pot crear nous usuaris"
      redirect '/'
    end

    mustache :user_create
  end

  post '/user/create' do
    env['warden'].authenticate!
    unless @current_user.admin?
      flash.error = "Un usuari no administrador no pot crear nous usuaris"
      redirect '/'
    end

    name = params['name']
    password = params['password']
    password_confirm = params['password_confirm']
    email = params['email']
    admin = params['admin'] || false
    if password != password_confirm
      flash[:error] = "Les contrasenyes no coincideixen"
      redirect '/user/create'
    end
    success = Models::User.create(
      :name => name,
      :email => email,
      :password => password,
      :created_at => Time.now,
      :updated_at => Time.now,
      :admin => admin
    )
    if success
      if admin
        flash.success = "Usuari administrador creat amb èxit"
      else
        flash.success = "Usuari creat amb èxit"
      end
      redirect '/users'
    else
      flash.error = "Hi ha hagut un problema. Comprova les dades"
      redirect '/user/create'
    end
  end

  post '/user/destroy' do
    env['warden'].authenticate!

    email = params['email']
    if @current_user.email == email
      flash.error = "No pots esborrar-te a tu mateix"
    else
      user = Models::User.first(:email => email)
      if user.destroy
        flash.success = "Usuari #{email} esborrat amb èxit"
      else
        flash.error = "No s'ha pogut esborrar l'usuari"
      end
    end
    redirect '/users'
  end

  get '/login' do
    mustache :login
  end

  post '/login' do
    env['warden'].authenticate!

    flash.success = "T'has indentificat amb èxit"
    if session[:return_to].nil?
      redirect '/'
    else
      redirect session[:return_to]
    end
  end

  get '/logout' do
    env['warden'].raw_session.inspect
    env['warden'].logout
    flash.success = "Has sortit amb èxit"
    redirect '/'
  end

  post '/logout' do
    redirect '/logout'
  end

  post '/unauthenticated' do
    session[:return_to] = env['warden.options'][:attempted_path]
    redirect '/login'
  end

  get '/users' do
    env['warden'].authenticate! # I <3 Ruby

    mustache :users
  end

  get '/point/create' do
    env['warden'].authenticate!

    mustache :point_create
  end

  post '/point/create' do
    env['warden'].authenticate!

    name = params['name']
    description = params['description']
    coord_x = params['coord_x']
    coord_y = params['coord_y']

    success = Models::Point.create(
      :name => name,
      :description => description,
      :coord_x => coord_x,
      :coord_y => coord_y,
      :created_at => Time.now,
      :updated_at => Time.now
    )

    if success
      redirect '/points'
    else
      redirect '/point/create'
    end
  end

  get '/image/create' do
    env['warden'].authenticate!

    mustache :image_create
  end

  post '/image/create' do
    env['warden'].authenticate!

    file = params['file'][:tempfile]
    filename = params['file'][:filename]
    extension = File.extname(filename)
    name = params['name']
    description = params['description']

    image = Models::Image.new(
      :name => name,
      :description => description,
      :created_at => Time.now,
      :updated_at => Time.now
    )
    image.save  # Now we'll have and ID

    image.path_tmp = File.join(::TMP_DIR, "#{image.id}.#{extension}")
    File.open(image.path_tmp, 'wb') do |f|
      f.write file.read
    end

    # If we're here, the upload was successful
    image.path = File.join(::MULTIMEDIA_DIR, "/#{image.id}.jpg")
    if image.save
      Workers::ImageConverter.perform_async(image.id)  # First Sidekiq usage here!
      redirect '/images'
    else
      redirect '/image/create'
    end
  end

  get '/video/create' do
    env['warden'].authenticate!

    mustache :video_create
  end

  post '/video/create' do
    env['warden'].authenticate!
    # TODO
  end

end
