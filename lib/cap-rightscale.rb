require 'yaml'
require 'pp'
require 'rubygems'
require 'right_resource'

$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'cap-rightscale/configuration'
Dir['cap-rightscale/recipes/*.rb'].each { |plugin| load(plugin) }
