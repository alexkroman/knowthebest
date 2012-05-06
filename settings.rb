['rubygems','sinatra','newrelic_rpm','amazon/ecs','google-search','exceptional','haml','sass','cgi','sinatra/sequel','model','net/http','net/https','digest/md5','padrino-helpers','sequel/extensions/pagination'].each {|x| require x}

class String
  def to_slug
    "best-" + self.gsub(/\W+/, '-').gsub(/^-+/,'').gsub(/-+$/,'').downcase
  end
end

configure do
  enable :sessions
  use Rack::Exceptional, '8bcc74dd78bbba04bb3597420a886046690e232c'
  Amazon::Ecs.configure do |options|
    options[:aWS_access_key_id] = ""
    options[:aWS_secret_key] = ""
  end
end

configure :development do
  database.logger = Logger.new(STDOUT) 
end

helpers do
  register Padrino::Helpers
end
