module Capistrano
  class Configuration
    module RightScale
      attr_writer :use_rs_cache
      attr_accessor :validate_echo, :use_nickname, :use_public_ip, :rs_confpath, :rs_lifetime, :rs_domain, :validate_resolv

      def rs_array_number_format(format)
        @array_num_format = format
      end

      [:rs_enable, :rs_disable].each do |method|
        define_method(method) do |*args|
          bool = method == :rs_enable ? true : false
          args.each {|arg| __send__("#{arg}=".to_sym, bool) if respond_to?("#{arg}=".to_sym) }
        end
      end

      # Get RightScale Server Array
      # RightScale nickname registerd deploy host's /etc/hosts
      # OR dns record(replace 's/ #/-000/' to ServerArray name)
      # === Parameters
      # * _role_ - Capistrano role symbol (ex. :app, :web, :db)
      # * _params[:array_id]_ - ex. :array_id => 1[https://my.rightscale.com/server_arrays/{id}]
      # * _params[:domain]_ domain name(user defined) - ex. :domain => "example.com"
      # * _params[:except_tags]_ except servers matching tags
      #   - ex. :except_tags => ["xx_app:state=broken", "xx_app:state=out_of_service"]
      # * _params[:xxx]_ - ex. :user => "www", :port => 2345, etc...
      # === Examples
      #   array_id = 1
      #   server_array :app, :array_id => array_id, :port => 1234
      def server_array(role, params)
start = Time.now
        _init unless initialized?
        return [] unless check_role(role)
        raise ArgumentError, ":array_id is not included in params!![#{params}]" unless params.has_key?(:array_id)
        @caller ||= File.basename(caller.map {|x| /(.*?):(\d+)/ =~ x; $1}.first, ".*")
        @rs_array_keys ||= [:array_id, :domain, :except_tags]

        logger.debug("SETTING ROLE: #{role}")

        servers = use_rs_cache ? role_with_load_cache(role, @rs_array_keys, params) : []

        if servers.size == 0
          # Request RightScale API
          array = rs_instance.array(params[:array_id])
          logger.debug("querying rightscale for server_array #{array.nickname}...")
          deployment = rs_instance.deployment(array.deployment_href.match(/[0-9]+$/).to_s, :server_settings => 'true')
          deployment_name = deployment.nickname
          logger.debug("Deployment #{deployment_name}:")
          servers = rs_instance.array_instances(array.id).select {|i| i[:state] == "operational" }
          servers = servers_with_tags_set(
            deployment.id, servers, params[:except_tags], :minus) if params.include?(:except_tags)

          servers = servers.map do |instance|
            hostname = instance[:nickname].sub(
              / #[0-9]+$/, array_number_format % instance[:nickname].match(/[0-9]+$/).to_s.to_i)
            dom = params[:domain] || rs_domain
            hostname += ".#{dom}" if dom
            ip = use_public_ip ? instance[:ip_address] : instance[:private_ip_address]

            logger.debug("Found server: #{instance[:nickname]}(#{ip})")
            use_nickname ? hostname : ip
          end
          servers = RSUtils.valid_resolv(servers, logger) if validate_resolv && use_nickname
          servers = RSUtils.valid_echo(servers, logger) if validate_echo

          role_with_dump_cache(role, servers, @rs_array_keys, params, use_rs_cache) if servers.size > 0
        end
logger.trace("Time: #{Time.now - start}")
        servers || []
      end

      # Get servers in deployment
      # === Parameters
      # * _role_ - Capistrano role symbol (ex. :app, :web, :db)
      # * _params[:name_prefix]_ - ex. :name_prefix => "db" (RightScale instance nickname)
      # * _params[:deployment]_ - ex. :deployment => 1[https://my.rightscale.com/deployments/{id}]
      # * _params[:domain]_ domain name(user defined) - ex. :domain => "example.com"
      # * _params[:except_tags]_ except servers matching tags
      #   - ex. :except_tags => ["xx_app:state=broken", "xx_app:state=out_of_service"]
      # * _params[:xxx]_ - ex. :user => "www", :port => 2345, etc...
      # === Examples
      #   deployment_id = 1
      #   nickname :db, :name_prefix => "db", :deployment => deployment_id, :user => "mysql"
      def nickname(role, params)
start = Time.now
        _init unless initialized?
        return [] unless check_role(role)
        raise ArgumentError, ":deployment is not included in params!![#{params}]" unless params.has_key?(:deployment)
        @caller ||= File.basename(caller.map {|x| /(.*?):(\d+)/ =~ x; $1 }.first, ".*")
        @rs_server_keys ||= [:array_id, :name_prefix, :domain, :except_tags]

        logger.debug("SETTING ROLE: #{role}")

        servers = use_rs_cache ? role_with_load_cache(role, @rs_server_keys, params) : []

        if servers.size == 0
          # Request RightScale API
          deployment = rs_instance.deployment(params[:deployment], :server_settings => 'true')
          logger.debug(
            "querying rightscale for servers #{params[:name_prefix]} in deployment #{deployment.nickname}...")
          servers = deployment.servers.select {|s| s[:state] == "operational" }
          servers = servers.select {|s| /#{params[:name_prefix]}/ =~ s[:nickname] } if params[:name_prefix]
          servers = servers_with_tags_set(
            params[:deployment], servers, params[:except_tags], :minus) if params.include?(:except_tags)

          servers = servers.map do |server|
            hostname = server[:nickname]
            dom = params[:domain] || rs_domain
            hostname += ".#{dom}" if dom
            ip = use_public_ip ? server[:settings][:ip_address] : server[:settings][:private_ip_address]

            logger.debug("Found server: #{server[:nickname]}(#{ip})")
            use_nickname ? hostname : ip
          end
          servers = RSUtils.valid_resolv(servers, logger) if validate_resolv && use_nickname
          servers = RSUtils.valid_echo(servers, logger) if validate_echo

          role_with_dump_cache(role, servers, @rs_server_keys, params, use_rs_cache) if servers.size > 0
        end
logger.trace("Time: #{Time.now - start}")
        servers || []
      end

      # Get servers matching tags in deployment
      # === Parameters
      # * _role_ - Capistrano role symbol (ex. :app, :web, :db)
      # * _params[:deployment]_ - ex. :deployment => 1[https://my.rightscale.com/deployments/{id}]
      # * _params[:tags]_ - ex. :tags => "xx_db:role=master",
      #     "xx_web:role", "xx_lb" (RightScale tags partial matchs 'namespece:predicate=value')
      # * _params[:name_prefix]_ - ex. :name_prefix => "db" (RightScale instance nickname)
      # * _params[:domain]_ domain name(user defined) - ex. :domain => "example.com"
      # * _params[:except_tags]_ except servers matching tags
      #   - ex. :except_tags => ["xx_app:state=broken", "xx_app:state=out_of_service"]
      # * _params[:xxx]_ - ex. :user => "www", :port => 2345, etc...
      # === Examples
      #   deployment_id = 1
      #   nickname :db, :name_prefix => "db",  :tags => "xx_db:role", :deployment => deployment_id, :port => 3306
      def tag(role, params)
start = Time.now
        _init unless initialized?
        return [] unless check_role(role)
        raise ArgumentError, ":tags is not included in params!![#{params}]" unless params.has_key?(:tags)
        raise ArgumentError, ":deployment is not included in params!![#{params}]" unless params.has_key?(:deployment)
        @caller ||= File.basename(caller.map {|x| /(.*?):(\d+)/ =~ x; $1 }.first, ".*")
        @rs_tag_keys ||= [:deployment, :tags, :name_prefix, :domain, :except_tags]

        logger.debug("SETTING ROLE: #{role}")

        servers = use_rs_cache ? role_with_load_cache(role, @rs_tag_keys, params) : []

        if servers.size == 0
          # Request RightScale API
          deployment = rs_instance.deployment(params[:deployment], :server_settings => 'true')
          logger.debug("querying rightscale for servers #{params[:name_prefix]} " +
            "matching tags #{params[:tags]} in deployment #{deployment.nickname}...")
          servers = deployment.servers.select {|s| s[:state] == "operational" }
          servers = servers.select {|s| /#{params[:name_prefix]}/ =~ s[:nickname] } if params[:name_prefix]

          servers = servers_with_tags_set(params[:deployment], servers, params[:tags], :intersect)
          if params.include?(:except_tags) && servers.size > 0
            servers = servers_with_tags_set(params[:deployment], servers, params[:except_tags], :minus)
          end

          servers = servers.map do |server|
            hostname = server[:nickname]
            dom = params[:domain] || rs_domain
            hostname += ".#{dom}" if dom
            ip = use_public_ip ? server[:settings][:ip_address] : server[:settings][:private_ip_address]

            logger.debug("Found server: #{server[:nickname]}(#{ip})")
            use_nickname ? hostname : ip
          end
          servers = RSUtils.valid_resolv(servers, logger) if validate_resolv && use_nickname
          servers = RSUtils.valid_echo(servers, logger) if validate_echo

          role_with_dump_cache(role, servers, @rs_tag_keys, params, use_rs_cache) if servers.size > 0
        end
logger.trace("Time: #{Time.now - start}")
        servers || []
      end

      private
      def check_role(role)
        return false if ENV['HOSTS']
        return false if ENV['ROLES'] && ENV['ROLES'].split(',').include?("#{role}") == false
        return true
      end

      def _init
        unless @initialized
          self.rs_confpath = fetch(:rs_confpath) rescue Capistrano::RightScale::RS_DEFAULT_CONFPATH
          self.rs_lifetime = fetch(:rs_lifetime) rescue Capistrano::RightScale::RS_DEFAULT_LIFETIME
          self.rs_lifetime = rs_cache_lifetime(rs_lifetime)
          self.rs_domain = fetch(:rs_domain) rescue nil
          rs_instance.confpath = rs_confpath
          cache_instance.lifetime = rs_lifetime

          @initialized = true
        end
      end

      def initialized?
        @initialized
      end

      # set cache lifetime
      # -1: infinity, 0: disable cache, '>0': lifetime(sec)
      def rs_cache_lifetime(time)
        t = time.to_i

        t = 0 if t < -1 # invalid value
        self.use_rs_cache = false if t == 0

        t
      end

      # Set Capistrano::Logger to instance for logging
      def rs_instance
        @rs_instance ||= Capistrano::RightScale::Resource.instance.instance_eval { @logger = logger; self }
      end

      def cache_instance
        @cache_instance ||= Capistrano::RightScale::Cache.instance.instance_eval { @logger = logger; self }
      end

      def role_with_load_cache(role, rs_keys, params)
        servers = cache_instance.load_server_cache(role, @caller) || []  # Get cache

        if servers.size > 0
          rs_keys.each {|key| params.delete(key) }  # remove rightscale's parameters
          servers.each {|s| logger.debug("restore server from cache: #{s}") }
          role(role, params) { servers }
        end

        servers
      end

      def role_with_dump_cache(role, servers, rs_keys, params, rs_cache=true)
        rs_keys.each {|key| params.delete(key) }  # remove rightscale's parameters
        role(role, params) { servers }
        cache_instance.dump_server_cache(role, servers, @caller) if rs_cache  # Dump cache
      end

      # set(union, intersect, minus) servers in deployment and servers matching tags in deployment
      def servers_with_tags_set(deployment_id, servers, tags, operator)
        tags_params = {:resource_type => "ec2_instance", :tags => tags}
        server_ids = servers.map {|s| s[:href].match(/[0-9]+$/).to_s }

        ts = servers_with_tags_in_deployment(deployment_id, tags_params)
        return {} if ts.size == 0

        ts_ids = ts.map {|s| s.href.sub("/current", "").match(/[0-9]+$/).to_s }
        case operator
        when :intersect then
          oper_ids = server_ids & ts_ids
        when :minus then
          oper_ids = server_ids - ts_ids
        end
        return {} if oper_ids.size == 0

        servers.select {|s| oper_ids.include?(s[:href].match(/[0-9]+$/).to_s) } || {}
      end

      def servers_with_tags_in_deployment(deployment_id, params)
        begin
          servers = rs_instance.tag(params).
            select {|s| s.state == "operational" }.
            select {|s| s.deployment_href.match(/[0-9]+$/).to_s == deployment_id.to_s }
        rescue
          {}
        end
        servers
      end

      def array_number_format
        @array_num_format ||= "%d"
      end

      def use_rs_cache
        if @use_rs_cache.nil? && ENV['RS_CACHE']
          env = ENV['RS_CACHE'].downcase
          @use_rs_cache = false if env == "false"
        end
        @use_rs_cache = true if @use_rs_cache.nil?
        @use_rs_cache
      end

      private :validate_echo, :use_nickname, :use_public_ip, :use_rs_cache, :validate_resolv
    end
  end
end
