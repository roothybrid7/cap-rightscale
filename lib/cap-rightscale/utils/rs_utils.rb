require 'thread'
require 'resolv'
require 'ping'

class RSUtils
  class << self
    def mk_rs_cache_dir(prefix=nil)
      tmpdir = Dir.tmpdir
      _prefix = prefix || "cap-rightscale"
      begin
        path = "#{tmpdir}/#{_prefix}-#{ENV['USER']}-#{rand(0x100000000).to_s(36)}"
        Dir.mkdir(path, 0700)
      rescue Errno::EEXIST
        STEDERR.puts(e)
        exit(1)
      end
    end

    def valid_resolv(servers, logger)
      hosts = servers
      @dns ||= Resolv::DNS.new

      hosts = hosts.map do |host|
        result = @dns.getaddress(host) rescue nil
        if result.nil?
          logger.debug("ResolvError: No address for #{host}")
          host = nil
        else
          logger.debug("Resolved server: #{host} => #{result}")
        end
        host
      end
      hosts.delete(nil)

      hosts || []
    end

    def valid_echo(servers, logger)
      hosts = servers
      threads = []

      hosts.each do |host|
        threads << Thread.new(host) {|h| Ping.pingecho(h) }
      end
      threads.each_with_index do |t,i|
        unless t.value
          logger.debug("Server dead or Network problem: #{hosts[i]}")
          hosts[i] = nil
        else
          logger.debug("Server alive: #{hosts[i]}")
        end
      end
      hosts.delete(nil)
      threads.clear

      hosts || []
    end
  end
end
