#
# Cookbook Name:: mongodb
# Definition:: mongodb
#
# Copyright 2011, edelight GmbH
# Authors:
#       Markus Korn <markus.korn@edelight.de>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

define :mongodb_instance, :mongodb_type => "mongod" , :action => [:enable, :start], :port => 27017 , \
    :logpath => "/log", :dbpath => "/data", :configfile => "/etc/mongodb.conf", \
    :configserver => [], :replicaset => nil, :enable_rest => false, \
    :notifies => [] do
    
  include_recipe "mongodb::default"
  
  name = params[:name]
  type = params[:mongodb_type]
  service_action = params[:action]
  service_notifies = params[:notifies]
  
  port = params[:port]

  logpath = params[:logpath]
  logfile = "#{logpath}/#{name}.log"
  
  dbpath = params[:dbpath]

  upstartfile = "/etc/init/#{name}.conf"
  
  configfile = params[:configfile]
  configserver_nodes = params[:configserver]

  enable_rest = params[:enable_rest]
  
  replicaset = params[:replicaset]
  if type == "shard"
    if replicaset.nil?
      replicaset_name = nil
    else
      # for replicated shards we autogenerate the replicaset name for each shard
      replicaset_name = "rs_#{replicaset['mongodb']['shard_name']}"
    end
  else
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
  end
  
  if !["mongod", "shard", "configserver", "mongos"].include?(type)
    raise "Unknown mongodb type '#{type}'"
  end
  
  if type != "mongos"
    daemon = "/usr/bin/mongod"
    configserver = nil
  else
    daemon = "/usr/bin/mongos"
    dbpath = nil
    configservers = configserver_nodes.collect{|n| "#{n['fqdn']}:#{n['mongodb']['port']}" }.join(",")
  end

  if type == "configserver"
    configsvr = true
  end
  
  if type == "shard"
    shardsvr = true
  end
  
  # log dir [make sure it exists]
  directory logpath do
    owner "mongodb"
    group "mongodb"
    mode "0755"
    action :create
    recursive true
  end
  
  if type != "mongos"
    # dbpath dir [make sure it exists]
    directory dbpath do
      owner "mongodb"
      group "mongodb"
      mode "0755"
      action :create
      recursive true
    end
  end

  if type != "mongos"
     template_source = "mongodb.config.erb"
  else
     template_source = "mongos.config.erb"
  end
  
  # Setup DB Config File
  template "#{configfile}" do
    action :create
    source template_source
    group node['mongodb']['root_group']
    owner "root"
    mode 0644
    variables(
      "dbpath"		=> dbpath,
      "logpath"		=> logfile,
      "port"		=> port,
      "configdb"	=> configservers,
      "replicaset_name"	=> replicaset_name,
      "configsvr"	=> configsvr,
      "shardsvr"	=> shardsvr,
      "enable_rest"	=> enable_rest
    )
    notifies :start, "service[#{name}]"
  end

  # Setup Upstart Config File
  # (use logpath, not logfile)
  template "#{upstartfile}" do
    action :create
    source "mongodb.upstart.erb"
    group node['mongodb']['root_group']
    owner "root"
    mode 0644
    variables(
      "daemon" => daemon,
      "dbpath" => dbpath,
      "logpath" => logpath
    )
    notifies :start, "service[#{name}]"
  end

  # service
  service name do
    provider Chef::Provider::Service::Upstart
    sleep(60)
    supports :status => true, :start => true
    action service_action
    notifies service_notifies
    if !replicaset_name.nil?
      notifies :create, "ruby_block[config_replicaset]"
    end
    if type == "mongos"
      notifies :create, "ruby_block[config_sharding]", :immediately
    end
    #if name == "mongodb"
      # we don't care about a running mongodb service in these cases, all we need is stopping it
    #  ignore_failure true
    #end
  end
  
  # replicaset
  if !replicaset_name.nil?
    rs_nodes = search(
      :node,
      "mongodb_cluster_name:#{replicaset['mongodb']['cluster_name']} AND \
       recipes:mongodb\\:\\:replicaset AND \
       mongodb_shard_name:#{replicaset['mongodb']['shard_name']} AND \
       chef_environment:#{replicaset.chef_environment}"
    )
  
    ruby_block "config_replicaset" do
      block do
        if not replicaset.nil?
          MongoDB.configure_replicaset(replicaset, replicaset_name, rs_nodes)
        end
      end
      action :nothing
    end
  end
  
  # sharding
  if type == "mongos"
    # add all shards
    # configure the sharded collections
    
    shard_nodes = search(
      :node,
      "mongodb_cluster_name:#{node['mongodb']['cluster_name']} AND \
       recipes:mongodb\\:\\:shard AND \
       chef_environment:#{node.chef_environment}"
    )
    
    ruby_block "config_sharding" do
      block do
        if type == "mongos"
          MongoDB.configure_shards(node, shard_nodes)
          MongoDB.configure_sharded_collections(node, node['mongodb']['sharded_collections'])
        end
      end
      action :nothing
    end
  end

if %w{ ubuntu debian }.include? node.platform
    ruby_block "uncomment_pam_limits" do
      block do
        f = Chef::Util::FileEdit.new('/etc/pam.d/su')
        f.search_file_replace(/^\#\s+(session\s+required\s+pam_limits.so)/, '\1')
        f.write_file
        Chef::Log.info("Updating pam_limits file if necessary")
       end
      only_if "egrep '^#\s+session\s+required\s+pam_limits\.so\s*$' /etc/pam.d/su"
     end
   end
end
