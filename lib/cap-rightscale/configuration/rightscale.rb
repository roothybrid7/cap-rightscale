require 'cap-rightscale/utils/rs_utils'
require 'cap-rightscale/configuration/rightscale/cache'
require 'cap-rightscale/configuration/rightscale/resource'

module Capistrano
  class Configuration
    module RightScale
      attr_reader :domainname
      attr_writer :validate_echo, :use_nickname, :use_public_ip, :use_rs_cache
      attr_accessor :rs_cache_lifetime

      def get_rs_confpath
        get_rs_instance.confpath
      end

      def set_rs_confpath(path)
        get_rs_instance.confpath = path
      end

      def rs_enable(*args)
        args.each do |arg|
          __send__("#{arg}=".to_sym, true) if respond_to?("#{arg}=".to_sym)
        end
      end

      def rs_disable(*args)
        args.each do |arg|
          __send__("#{arg}=".to_sym, false) if respond_to?("#{arg}=".to_sym)
        end
      end

      def rs_cache_lifetime(time)
        get_cache_instance.lifetime = time  # seconds
      end

      def set_domainname(domain)
        @domainname = domain
      end

      # Get RightScale Server Array
      # === Parameters
      # * _role_ - Capistrano role symbol (ex. :app, :web, :db)
      # * _params[:array_id]_ - ex. :array_id => 1[https://my.rightscale.com/server_arrays/{id}]
      # * _params[:xxx]_ - ex. :user => "www", :port => 2345, etc...
      # === Examples
      #   array_id = 1
      #   server_array :app, :array_id => array_id, :port => 1234
      def server_array(role, params)
        return [] unless check_role(role)
        raise ArgumentError, ":array_id is not included in params!![#{params}]" unless params.has_key?(:array_id)
        @caller ||= File.basename(caller.map {|x| /(.*?):(\d+)/ =~ x; $1}.first, ".*")

start = Time.now
        logger.info("SETTING ROLE: #{role}")

        host_list = use_rs_cache ? get_cache_instance.load_server_cache(role, @caller) : []  # Get cache

        if host_list.size > 0
          [:array_id, :except_tags].each {|key| params.delete(key)}  # remove rightscale's parameters
          logger.info("restore cache of servers:\n#{host_list.pretty_inspect}")
          role(role, params) { host_list }  # set cache to role()
        else
          # Request RightScale API
          array = get_rs_instance.array(params[:array_id])
          logger.info("querying rightscale for server_array #{array.nickname}...")
          dept = get_rs_instance.deployment(array.deployment_href.match(/[0-9]+$/).to_s, :server_settings => 'true')
          deployment_name = dept.nickname
          logger.info("Deployment #{deployment_name}:")
          srvs = get_rs_instance.array_instances(array.id).select {|i| i[:state] == "operational"}

          if params.include?(:except_tags)
            except_tags_params = {:resource_type => "ec2_instance", :tags => params[:except_tags]}
            srvs = servers_with_tags_set(params[:deployment], srvs, except_tags_params, :minus)
            return [] if srvs.size == 0  # Not found servers matching tag
          end

          host_list = srvs.map do |instance|
            hostname = instance[:nickname].sub(/ #[0-9]+$/, "-%03d" % instance[:nickname].match(/[0-9]+$/).to_s.to_i)
            hostname << ".#{domainname}" if domainname && hostname.match(/#{domainname}/).nil?
            ip = use_public_ip ? instance[:ip_address] : instance[:private_ip_address]

            logger.info("Found server: #{hostname}(#{ip})")
            use_nickname ? hostname : ip
          end
          host_list = RSUtils.valid_echo(host_list, logger) if validate_echo

          if host_list.size > 0
            [:array_id, :except_tags].each {|key| params.delete(key)}  # remove rightscale's parameters
            role(role, params) { host_list }
            get_cache_instance.dump_server_cache(role, host_list, @caller) if use_rs_cache  # Dump cache
          end
        end
logger.debug("Time: #{Time.now - start}")
        host_list || []
      end

      # Get servers in deployment
      # === Parameters
      # * _role_ - Capistrano role symbol (ex. :app, :web, :db)
      # * _params[:name_prefix]_ - ex. :name_prefix => "db" (RightScale instance nickname)
      # * _params[:deployment]_ - ex. :deployment => 1[https://my.rightscale.com/deployments/{id}]
      # * _params[:xxx]_ - ex. :user => "www", :port => 2345, etc...
      # === Examples
      #   deployment_id = 1
      #   nickname :db, :name_prefix => "db", :deployment => deployment_id, :user => "mysql"
      def nickname(role, params)
        return [] unless check_role(role)
        raise ArgumentError, ":deployment is not included in params!![#{params}]" unless params.has_key?(:deployment)
        @caller ||= File.basename(caller.map {|x| /(.*?):(\d+)/ =~ x; $1}.first, ".*")

start = Time.now
        logger.info("SETTING ROLE: #{role}")

        host_list = use_rs_cache ? get_cache_instance.load_server_cache(role, @caller) : []  # Get cache

        if host_list.size > 0
          [:deployment, :name_prefix, :except_tags].each {|key| params.delete(key)}  # remove rightscale's parameters
          logger.info("restore cache of servers:\n#{host_list.pretty_inspect}")
          role(role, params) { host_list }  # set cache to role()
        else

          # Request RightScale API
          dept = get_rs_instance.deployment(params[:deployment], :server_settings => 'true')
          logger.info("querying rightscale for servers #{params[:name_prefix]} in deployment #{dept.nickname}...")
          srvs = dept.servers.select {|s| s[:state] == "operational"}
          srvs = srvs.select {|s| /#{params[:name_prefix]}/ =~ s[:nickname]} if params[:name_prefix]

          if params.include?(:except_tags)
            except_tags_params = {:resource_type => "ec2_instance", :tags => params[:except_tags]}
            srvs = servers_with_tags_set(params[:deployment], srvs, except_tags_params, :minus)
            return [] if srvs.size == 0  # Not found servers matching tag
          end

          host_list = srvs.map do |server|
            hostname = server[:nickname].sub(/ #[0-9]+$/, "-%03d" % server[:nickname].match(/[0-9]+$/).to_s.to_i)
            hostname << ".#{domainname}" if domainname && hostname.match(/#{domainname}/).nil?
            ip = use_public_ip ? server[:settings][:ip_address] : server[:settings][:private_ip_address]

            logger.info("Found server: #{hostname}(#{ip})")
            use_nickname ? hostname : ip
          end
          host_list = RSUtils.valid_echo(host_list, logger) if validate_echo

          if host_list.size > 0
            [:array_id, :except_tags].each {|key| params.delete(key)}  # remove rightscale's parameters
            role(role, params) { host_list }
            get_cache_instance.dump_server_cache(role, host_list, @caller) if use_rs_cache  # Dump cache
          end
        end
logger.debug("Time: #{Time.now - start}")
        host_list || []
      end

      # Get servers matching tags in deployment
      # === Parameters
      # * _role_ - Capistrano role symbol (ex. :app, :web, :db)
      # * _params[:tags]_ - ex. :tags => "xx_db:role=master",
      #     "xx_web:role", "xx_lb" (RightScale tags partial matchs 'namespece:predicate=value')
      # * _params[:deployment]_ - ex. :deployment => 1[https://my.rightscale.com/deployments/{id}]
      # * _params[:xxx]_ - ex. :user => "www", :port => 2345, etc...
      # === Examples
      #   deployment_id = 1
      #   nickname :db, :tags => "xx_db:role", :deployment => deployment_id, :port => 3306
      def tag(role, params)
        return [] unless check_role(role)
        raise ArgumentError, ":tags is not included in params!![#{params}]" unless params.has_key?(:tags)
        raise ArgumentError, ":deployment is not included in params!![#{params}]" unless params.has_key?(:deployment)
        @caller ||= File.basename(caller.map {|x| /(.*?):(\d+)/ =~ x; $1}.first, ".*")

start = Time.now
        logger.info("SETTING ROLE: #{role}")

        host_list = use_rs_cache ? get_cache_instance.load_server_cache(role, @caller) : []  # Get cache

        if host_list.size > 0
          [:deployment, :tags, :except_tags].each {|key| params.delete(key)}  # remove rightscale's parameters
          logger.info("restore cache of servers:\n#{host_list.pretty_inspect}")
          role(role, params) { host_list }  # set cache to role()
        else
          # Request RightScale API
          dept = get_rs_instance.deployment(params[:deployment], :server_settings => 'true')
          logger.info("querying rightscale for servers matching tags #{params[:tags]} in deployment #{dept.nickname}...")
          srvs = dept.servers.select {|s| s[:state] == "operational"}

          ts_params = {:resource_type => "ec2_instance", :tags => params[:tags]}
          srvs = servers_with_tags_set(params[:deployment], srvs, ts_params, :intersect)
          return [] if srvs.size == 0  # Not found servers matching tag

          if params.include?(:except_tags)
            except_tags_params = {:resource_type => "ec2_instance", :tags => params[:except_tags]}
            srvs = servers_with_tags_set(params[:deployment], srvs, except_tags_params, :minus)
            return [] if srvs.size == 0  # Not found servers matching tag
          end

          host_list = srvs.map do |server|
            hostname = server[:nickname]
            hostname << ".#{domainname}" if domainname && hostname.match(/#{domainname}/).nil?
            ip = use_public_ip ? server[:settings][:ip_address] : server[:settings][:private_ip_address]

            logger.info("Found server: #{hostname}(#{ip})")
            use_nickname ? hostname : ip
          end

          host_list = RSUtils.valid_echo(host_list, logger) if validate_echo

          if host_list.size > 0
            [:deployment, :tags, :except_tags].each {|key| params.delete(key)}  # remove rightscale's parameters
            role(role, params) { host_list }
            get_cache_instance.dump_server_cache(role, host_list, @caller) if use_rs_cache  # Dump cache
          end
        end
logger.debug("Time: #{Time.now - start}")
        host_list || []
      end

      private
        def check_role(role)
          return false if ENV['HOSTS']
          return false if ENV['ROLES'] && ENV['ROLES'].split(',').include?("#{role}") == false
          return true
        end

        def get_rs_instance
          @rs_instance ||= Capistrano::RightScale::Resource.instance
        end

        def get_cache_instance
          @cache_instance ||= Capistrano::RightScale::Cache.instance
        end

        # set(union, intersect, minus) servers in deployment and servers matching tags in deployment
        def servers_with_tags_set(deployment_id, servers, tags_params, operator)
          servers_ids = servers.map {|s| s[:href].match(/[0-9]+$/).to_s}

          ts = servers_with_tags_in_deployment(deployment_id, tags_params)
          return [] if ts.size == 0

          ts_ids = ts.map {|s| s.href.sub("/current", "").match(/[0-9]+$/).to_s}
          case operator
          when :intersect then
            oper_ids = servers_ids & ts_ids
          when :minus then
            oper_ids = servers_ids - ts_ids
          end
          return [] if oper_ids.size == 0

          servers.select {|s| oper_ids.include?(s[:href].match(/[0-9]+$/).to_s)} || []
        end

        def intersect_servers_with_tags(deployment, servers, tags_params, tags_api)
          ts = tags_api.call
          return [] if ts.size == 0

          ts_ids = ts.map {|s| s.href.sub("/current", "").match(/[0-9]+$/).to_s}
          intersect_ids = servers_ids & ts_ids
          intersect_ids.size > 0 ? intersect_ids : []
        end

        def servers_with_tags_in_deployment(deployment_id, params)
          begin
            servers = get_rs_instance.tag(params).
              select {|s| s.state == "operational"}.
              select {|s| s.deployment_href.match(/[0-9]+$/).to_s == deployment_id.to_s}
          rescue => e
            {}
          end
          servers
        end

        def validate_echo
          @validate_echo ||= false
        end

        # register deploy host's /etc/hosts OR dns record(replace 's/ #/-000/' to ServerArray name)
        def use_nickname
          @use_nickname ||= false
        end

        def use_public_ip
          @use_public_ip ||= false
        end

        def use_rs_cache
          if @use_rs_cache.nil? && ENV['RSCACHE']
            env = ENV['RSCACHE'].downcase
            @use_rs_cache = false if env == "false"
          end
          @use_rs_cache = true if @use_rs_cache.nil?
          @use_rs_cache
        end
    end
  end
end
