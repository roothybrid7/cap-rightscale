require 'yaml'
require 'pp'
require 'rubygems'
require 'right_resource'

$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'cap-rightscale/configuration'
require 'cap-rightscale/utils/rs_utils'

module Capistrano
  module RightScale
    RS_DEFAULT_CONFPATH = File.join(ENV['HOME'], ".rsconf", "rsapiconfig.yml")
    RS_DEFAULT_LIFETIME = 86400
  end
end
