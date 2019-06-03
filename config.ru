require File.expand_path "../main.rb", __FILE__
require 'rack'
require 'rack/contrib'

use Rack::PostBodyContentTypeParser

run Rack::URLMap.new({
                       "/api" => Api
                     })
