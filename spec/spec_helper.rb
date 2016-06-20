require 'bundler'
Bundler.require :test

Dir['./spec/support/**/*.rb'].each { |f| require f }

RSpec.configure do |config|

end
