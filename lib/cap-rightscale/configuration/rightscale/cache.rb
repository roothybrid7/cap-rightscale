require 'singleton'

module Capistrano
  module RightScale
    class Cache
      include Singleton

      attr_accessor :lifetime, :logger
      attr_reader :array, :array_instances, :deployment

      def initialize
        @lifetime = Capistrano::RightScale::RS_DEFAULT_LIFETIME
      end

      def load_server_cache(role, prefix=nil)
        server_cache = self.instance_variable_get("@#{role}_cache")

        begin
          cache_files = Dir.glob("#{Dir.tmpdir}/cap-rightscale-#{ENV['USER']}-*/#{prefix}*#{role}.cache")

          if cache_files.size > 0 && !server_cache
            c = Marshal.load(open(cache_files.first) {|f| f.read })
            self.instance_variable_set("@#{role}_cache", c)
          end
          server_cache = self.instance_variable_get("@#{role}_cache")
          return [] unless server_cache # No cache entry

          # get servers
          servers = server_cache[role][:servers].size > 0 ? server_cache[role][:servers] : []
          if lifetime > 0 && Time.now - server_cache[role][:cache] > lifetime
            servers = []
          end
        rescue => e
          return [] unless server_cache
        end

        servers
      end

      def dump_server_cache(role, servers, prefix=nil)
        h = {role => {:servers => servers, :cache => Time.now}}
        obj_dump = Marshal.dump(h)

        # Get cache directory
        cache_dir = Dir.glob("#{Dir.tmpdir}/cap-rightscale-#{ENV['USER']}-*").first
        if cache_dir.nil?
          RSUtils.mk_rs_cache_dir
          cache_dir = Dir.glob("#{Dir.tmpdir}/cap-rightscale-#{ENV['USER']}-*").first
          exit if cache_dir.nil?
        end
        cache_file = File.join(cache_dir, "#{prefix}-#{role}.cache")

        begin
          open(cache_file, "w") {|f| f.write(obj_dump)}
        rescue => e
          @logger.important("#{e.class}: #{e.pretty_inspect}")
          @logger.trace("Backtrace:\n#{e.backtrace.pretty_inspect}")
        end
      end

      private
      def logger
        @logger ||= Capistrano::Logger.new
      end
    end
  end
end
