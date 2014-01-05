class Chef
  class Resource::MongodbInstance < Resource
    include Poise
    actions(:enable, :start, :stop, :disable, :status, :restart)

    attribute(:configserver_nodes, kind_of: Array, default: [])
    attribute(:dbpath, kind_of: String, default: '/data')
    attribute(:logpath, kind_of: String, default: '/var/log/mongodb')
    attribute(:replicaset, kind_of: [Array, NilClass], default: nil)
    attribute(:service_action, kind_of: Array, default: [:enable, :start])
    attribute(:service_notifies, kind_of: Array, default: [])

    attribute(:auto_configure_replicaset, kind_of: [TrueClass, FalseClass], default: lazy { node['mongodb']['auto_configure']['replicaset'] })
    attribute(:auto_configure_sharding, kind_of: [TrueClass, FalseClass], default: lazy { node['mongodb']['auto_configure']['sharding'] })
    attribute(:cluster_name, kind_of: String, default: lazy { node['mongodb']['cluster_name'] })
    attribute(:dbconfig_file, kind_of: String, default: lazy { node['mongodb']['dbconfig_file'] })
    attribute(:dbconfig_file_template, kind_of: String, default: lazy { node['mongodb']['dbconfig_file_template'] })
    attribute(:init_dir, kind_of: String, default: lazy { node['mongodb']['init_dir'] })
    attribute(:init_script_template, kind_of: String, default: lazy { node['mongodb']['init_script_template'] })
    attribute(:mongodb_user, kind_of: String, default: lazy { node['mongodb']['user'] })
    attribute(:mongodb_group, kind_of: String, default: lazy { node['mongodb']['group'] })
    attribute(:root_group, kind_of: String, default: lazy { node['mongodb']['root_group'] })
    attribute(:sharded_collections, kind_of: String, default: lazy { node['mongodb']['sharded_collections'] })
    attribute(:sysconfig_file, kind_of: String, default: lazy { node['mongodb']['sysconfig_file'] })
    attribute(:sysconfig_file_template, kind_of: String, default: lazy { node['mongodb']['sysconfig_file_template'] })
    attribute(:sysconfig_vars, kind_of: Hash, default: lazy { node['mongodb']['sysconfig'] })
    attribute(:template_cookbook, kind_of: String, default: lazy { node['mongodb']['template_cookbook'] })

    def init_file
      if node['mongodb']['apt_repo'] == "ubuntu-upstart" then
        init_file = ::File.join(init_dir, "#{name}.conf")
      else
        init_file = ::File.join(init_dir, name)
      end
    end
    def replicaset_name
      # if there is a predefined replicaset name we use it,
      # otherwise we try to generate one using 'rs_$SHARD_NAME'
      begin
        replicaset_name = replicaset['mongodb']['replicaset_name']
      rescue
        replicaset_name = nil
      end
      if replicaset_name.nil?
        begin
          replicaset_name = "rs_#{replicaset['mongodb']['shard_name']}"
        rescue
          replicaset_name = nil
        end
      end
      return replicaset_name
    end

    def replicaset_nodes
      search(
        :node,
        "mongodb_cluster_name:#{new_resource.replicaset['mongodb']['cluster_name']} AND \
         mongodb_is_replicaset:true AND \
         mongodb_shard_name:#{new_resource.replicaset['mongodb']['shard_name']} AND \
         chef_environment:#{new_resource.replicaset.chef_environment}"
      )
    end

    def shard_nodes
      search(
        :node,
        "mongodb_cluster_name:#{new_resource.cluster_name} AND \
         mongodb_is_shard:true AND \
         chef_environment:#{node.chef_environment}"
      )
    end

    def provides
      "mongod"
    end

    def should_configure_sharding?
      false
    end

    def should_configure_replicaset?
      !replicaset_name.nil? && auto_configure_replicaset
    end
  end
  class Provider::MongodbInstance < Provider
    include Poise::Provider
    def action_enable
      converge_by("enable mongodb instance #{new_resource.name}") do
        notifying_block do
          create_configs
          ensure_dbpath
          configure_replicaset
          configure_sharding

          enable_service
        end
      end
    end

    def action_start
      converge_by("enable mongodb instance #{new_resource.name}") do
        notifying_block do
          create_configs
          ensure_dbpath
          configure_replicaset
          configure_sharding

          start_service
        end
      end
    end

    def action_restart
      converge_by("enable mongodb instance #{new_resource.name}") do
        notifying_block do
          restart_service
        end
      end
    end

    def action_disable
      converge_by("enable mongodb instance #{new_resource.name}") do
        notifying_block do
          disable_service
        end
      end
    end

    def action_stop
      converge_by("enable mongodb instance #{new_resource.name}") do
        notifying_block do
          stop_service
        end
      end
    end

    private

    def create_configs
      # default file
      template new_resource.sysconfig_file do
        cookbook new_resource.template_cookbook
        source new_resource.sysconfig_file_template
        group new_resource.root_group
        owner "root"
        mode "0644"
        variables(
          "sysconfig" => new_resource.sysconfig_vars
        )
        # notifies :restart, "service[#{new_resource.name}]"
      end

      # config file
      template new_resource.dbconfig_file do
        cookbook new_resource.template_cookbook
        source new_resource.dbconfig_file_template
        group new_resource.root_group
        owner "root"
        mode "0644"
      end

      # init script
      template new_resource.init_file do
        cookbook new_resource.template_cookbook
        source new_resource.init_script_template
        group new_resource.root_group
        owner "root"
        mode "0755"
        variables(
          provides: new_resource.provides
        )
        # notifies :restart, "service[#{new_resource.name}]"
      end

      # log dir [make sure it exists]
      directory new_resource.logpath do
        owner new_resource.mongodb_user
        group new_resource.mongodb_group
        mode "0755"
        action :create
        recursive true
      end
    end

    def configure_replicaset
      @configure_replicaset ||= ruby_block "config_replicaset" do
        block do
          if not new_resource.replicaset.nil?
            MongoDB.configure_replicaset(new_resource.replicaset, new_resource.replicaset_name, new_resource.replicaset_nodes)
          end
        end
        only_if { new_resource.should_configure_replicaset? }
        action :nothing
      end
    end


    def configure_sharding
      @configure_sharding ||= ruby_block "config_sharding" do
        block do
          # nop, only used in mongos
        end
        only_if { new_resource.should_configure_sharding? }
        action :nothing
      end
    end

    def ensure_dbpath
      # dbpath dir [make sure it exists]
      directory new_resource.dbpath do
        owner new_resource.mongodb_user
        group new_resource.mongodb_group
        mode "0755"
        action :create
        recursive true
      end
    end

    def enable_service
      service new_resource.name do
        supports :status => true, :restart => true
        action :enable
        new_resource.service_notifies.each do |service_notify|
          notifies :run, service_notify
        end
        if new_resource.should_configure_replicaset?
          notifies :create, config_replicaset
        end
        if new_resource.should_configure_sharding?
          notifies :create, configure_sharding, :immediately
        end
        if new_resource.name == "mongodb"
          # we don't care about a running mongodb service in these cases, all we need is stopping it
          ignore_failure true
        end
      end
    end

    def start_service
      s = enable_service
      s.action :start
      s
    end

    def restart_service
      s = enable_service
      s.action :restart
      s
    end

    def status_service
      s = enable_service
      s.action :status
      s
    end

    def disable_service
      s = enable_service
      s.action :disable
      s
    end

    def stop_service
      s = enable_service
      s.action :stop
      s
    end
  end
end
