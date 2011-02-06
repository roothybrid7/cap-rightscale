require 'cap-rightscale/configuration/rightscale'
require 'cap-rightscale/configuration/rightscale/cache'
require 'cap-rightscale/configuration/rightscale/resource'

module Capistrano
  class Configuration
    include RightScale
  end
end
