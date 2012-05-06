require 'application'
require "rack/test"
require "webrat"
require "test/unit"

Webrat.configure do |config|
  config.mode = :rack
end

class AppTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include Webrat::Methods
  include Webrat::Matchers

  def app
    Sinatra::Application.new
  end
  
  def test_it_works
    visit "/"
    assert last_response.ok?
  end
  
end