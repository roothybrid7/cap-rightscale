module Capistrano
  class Configuration
    module RightScale
      def get_rs_confpath
        @rs_confpath ||= File.join(ENV['HOME'], ".rsconf", "rsapiconfig.yml")
      end

      def set_rs_confpath(path)
        @rs_confpath = path
      end

      # register deploy host's /etc/hosts OR dns record(replace 's/ #/-000/' to ServerArray name)
      def use_nickname(bool=false)
        @use_nick = bool
      end

      def domainname(domain)
        @domain = domain
      end

      def connect
        @auth ||= open(get_rs_confpath) {|f| YAML.load(f)}
        @conn ||= RightResource::Connection.new do |c|
          c.login(:username => @auth["username"], :password => @auth["password"], :account => @auth["account"])
        end

        RightResource::Base.connection = @conn
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

start = Time.now
        connect
        logger.info("SETTING ROLE: #{role}")
        array = ServerArray.show(params[:array_id])
        logger.info("querying rightscale for server_array #{array.nickname}...")
        deployment_name = Deployment.show(array.deployment_href.match(/[0-9]+$/).to_s).nickname
        logger.info("Deployment #{deployment_name}:")

        params.delete(:array_id)  # remove rightscale's parameters

        host_list = ServerArray.instances(array.id).select {|i| i[:state] == "operational"}.map do |instance|
          hostname = instance[:nickname].sub(/ #[0-9]+$/, "-%03d" % instance[:nickname].match(/[0-9]+$/).to_s.to_i)
          hostname << ".#{_domain}" if _domain
          ip = instance[:private_ip_address]
          logger.info("Found server: #{hostname}(#{ip})")
          enable_hostname ? hostname : ip
        end
        role(role, params) { host_list } if host_list
puts "Time: #{Time.now - start}"
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

start = Time.now
        connect
        logger.info("SETTING ROLE: #{role}")
        dept = Deployment.show(params[:deployment], :server_settings => 'true')
        logger.info("querying rightscale for servers #{params[:name_prefix]} in deployment #{dept.nickname}...")
        srvs = dept.servers.select {|s| s[:state] == "operational"}
        srvs = srvs.select {|s| /#{params[:name_prefix]}/ =~ s[:nickname]} if params[:name_prefix]

        # remove rightscale's parameters
        params.delete(:deployment)
        params.delete(:name_prefix) if params.has_key?(:name_prefix)

        host_list = srvs.map do |server|
          hostname = server[:nickname]
          hostname << ".#{_domain}" if _domain
puts hostname
          ip = server[:settings][:private_ip_address]
          logger.info("Found server: #{hostname}(#{ip})")
          enable_hostname ? hostname : ip
        end
        role(role, params) { host_list } if host_list
puts "Time: #{Time.now - start}"
        host_list || []
      end

      # Get servers matching tags in deployment
      # === Parameters
      # * _role_ - Capistrano role symbol (ex. :app, :web, :db)
      # * _params[:tags]_ - ex. :tags => "xx_db:role=master", "xx_web:role", "xx_lb" (RightScale tags partial matchs 'namespece:predicate=value')
      # * _params[:deployment]_ - ex. :deployment => 1[https://my.rightscale.com/deployments/{id}]
      # * _params[:xxx]_ - ex. :user => "www", :port => 2345, etc...
      # === Examples
      #   deployment_id = 1
      #   nickname :db, :tags => "xx_db:role", :deployment => deployment_id, :port => 3306
      def tag(role, params)
        return [] unless check_role(role)
        raise ArgumentError, ":tags is not included in params!![#{params}]" unless params.has_key?(:tags)
        raise ArgumentError, ":deployment is not included in params!![#{params}]" unless params.has_key?(:deployment)

start = Time.now
        connect
        logger.info("SETTING ROLE: #{role}")
        dept = Deployment.show(params[:deployment], :server_settings => 'true')
        logger.info("querying rightscale for servers matching tags #{params[:tags]} in deployment #{dept.nickname}...")
        srvs = dept.servers.select {|s| s[:state] == "operational"}

        ts_params = {:resource_type => "ec2_instance", :tags => [params[:tags]]}
        ts = Tag.search(ts_params).
          select {|s| s.state == "operational"}.
          select {|s| s.deployment_href.match(/[0-9]+$/).to_s == params[:deployment].to_s}

        # diff servers in deployment and servers matching tags in deployment
        srvs_ids = srvs.map {|s| s[:href].match(/[0-9]+$/).to_s}
        ts_ids = ts.map {|s| s.href.sub("/current", "").match(/[0-9]+$/).to_s}
        found_ids = srvs_ids & ts_ids

        # remove rightscale's parameters
        params.delete(:deployment)
        params.delete(:tags)

        host_list = []
        if found_ids.size > 0
          host_list = srvs.select {|s| found_ids.include?(s[:href].match(/[0-9]+$/).to_s)}.map do |server|
            hostname = server[:nickname]
            hostname << ".#{_domain}" if _domain
            ip = server[:settings][:private_ip_address]
            logger.info("Found server: #{hostname}(#{ip})")
            enable_hostname ? hostname : ip
          end

          role(role, params) { host_list } if host_list
        end
puts "Time: #{Time.now - start}"
        host_list || []
      end

      private
        def enable_hostname
          @use_nick ||= false
        end

        def _domain
          @domain || nil
        end

        def check_role(role)
          return false if ENV['HOSTS']
          return false if ENV['ROLES'] && ENV['ROLES'].split(',').include?("#{role}") == false
          return true
        end
    end
  end
end
