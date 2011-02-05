require 'singleton'

module Capistrano
  module RightScale
    class Resource
      include Singleton

      attr_accessor :confpath
      attr_reader :array, :array_instances, :deployment
      def initialize
        @confpath = File.join(ENV['HOME'], ".rsconf", "rsapiconfig.yml")
      end

      def connect
        begin
          @auth ||= open(confpath) {|f| YAML.load(f)}
          @conn ||= RightResource::Connection.new do |c|
            c.login(:username => @auth["username"], :password => @auth["password"], :account => @auth["account"])
          end
        rescue => e
          auth_data = open(File.join(File.expand_path(
            File.dirname(__FILE__)), '/../../../../rsapiconfig.yml.sample')) {|f| f.read}
          STDERR.puts <<-"USAGE"
Cannot load RightScale API credentials!!:
  Put authfile:<rsapiconfig.yml> in <HOME>/.rsconf/
    OR
  Set param: set_rs_confpath <authfile_path>

Authfile contents: specify your Rightscale API credentials
#{auth_data}
USAGE
          exit(1)
        end
        RightResource::Base.connection = @conn
      end

      def _instance_variable_set(method, id, api)
        connect
        begin
          self.instance_variable_set("@#{method}_#{id}", api.call)
        rescue => e
          STDERR.puts("#{e.class}: #{e.pretty_inspect}")
          STDERR.puts("Backtrace:\n#{e.backtrace.pretty_inspect}")
          exit(1)
        end

        status_code = RightResource::Base.status_code
        if status_code.nil?
          STDERR.puts("Errors: Unknown Errors")
          exit(1)
        elsif status_code != 200
          STDERR.puts("Errors: HTTP STATUS CODE is #{status_code}")
          STDERR.puts(RightResource::Base.headers)
          exit(1)
        end

        data = self.instance_variable_get("@#{method}_#{id}")
        data
      end

      def array(id)
        _instance_variable_set(:array, id, lambda {ServerArray.show(id)}) unless
          self.instance_variable_get("@array_#{id}")
        self.instance_variable_get("@array_#{id}")
      end

      def array_instances(id)
        _instance_variable_set(:array_instances, id,
          lambda {ServerArray.instances(id)}) unless self.instance_variable_get("@array_instances_#{id}")
        self.instance_variable_get("@array_instances_#{id}")
      end

      def deployment(id, params)
        _instance_variable_set(:deployment, id,
          lambda {Deployment.show(id, params)}) unless self.instance_variable_get("@deployment_#{id}")
        self.instance_variable_get("@deployment_#{id}")
      end

      def tag(params)
        begin
          tags = Tag.search(params)  # not stored
        rescue => e
          STDERR.puts("#{e.class}: #{e.pretty_inspect}")
          STDERR.puts("Backtrace:\n#{e.backtrace.pretty_inspect}")
          exit(1)
        end

        status_code = Tag.status_code
        if status_code.nil?
          STDERR.puts("Errors: Unknown Errors")
          exit(1)
        elsif status_code != 200
          STDERR.puts("Errors: HTTP STATUS CODE is #{status_code}")
          STDERR.puts(Tag.headers)
          exit(1)
        end
        tags
      end
    end
  end
end
