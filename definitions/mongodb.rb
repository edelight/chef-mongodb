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

define :mongodb_instance,
    :mongodb_type  => "mongod",
    :action        => [:enable, :start],
    :logpath       => "/var/log/mongodb",
    :dbpath        => "/data",
    :configserver  => [],
    :replicaset    => nil,
    :notifies      => [] do

  if !["mongod", "shard", "configserver", "mongos"].include?(params[:mongodb_type])
    raise ArgumentError, ":mongodb_type must be 'mongod', 'shard', 'configserver' or 'mongos'; was #{params[:mongodb_type].inspect}"
  end

  require 'ostruct'

  include_recipe "mongodb::default"

  new_resource = OpenStruct.new

  new_resource.name                       = params[:name]
  new_resource.configserver_nodes         = params[:configserver]
  new_resource.dbpath                     = params[:dbpath]
  new_resource.logpath                    = params[:logpath]
  new_resource.replicaset                 = params[:replicaset]
  new_resource.service_action             = params[:action]
  new_resource.service_notifies           = params[:notifies]
  new_resource.type                       = params[:mongodb_type]

  # TODO(jh): parameterize so we can make a resource provider
  new_resource.auto_configure_replicaset  = node['mongodb']['auto_configure']['replicaset']
  new_resource.auto_configure_sharding    = node['mongodb']['auto_configure']['sharding']
  new_resource.cluster_name               = node['mongodb']['cluster_name']
  new_resource.dbconfig_file              = node['mongodb']['dbconfig_file']
  new_resource.dbconfig_file_template     = node['mongodb']['dbconfig_file_template']
  new_resource.init_dir                   = node['mongodb']['init_dir']
  new_resource.init_script_template       = node['mongodb']['init_script_template']
  new_resource.is_replicaset              = node['mongodb']['is_replicaset']
  new_resource.is_shard                   = node['mongodb']['is_shard']
  new_resource.mongodb_group              = node['mongodb']['group']
  new_resource.mongodb_user               = node['mongodb']['user']
  new_resource.replicaset_name            = node['mongodb']['replicaset_name']
  new_resource.root_group                 = node['mongodb']['root_group']
  new_resource.shard_name                 = node['mongodb']['shard_name']
  new_resource.sharded_collections        = node['mongodb']['sharded_collections']
  new_resource.sysconfig_file             = node['mongodb']['sysconfig_file']
  new_resource.sysconfig_file_template    = node['mongodb']['sysconfig_file_template']
  new_resource.sysconfig_vars             = node['mongodb']['sysconfig']
  new_resource.template_cookbook          = node['mongodb']['template_cookbook']


  if node['mongodb']['apt_repo'] == "ubuntu-upstart" then
    new_resource.init_file = File.join(node['mongodb']['init_dir'], "#{new_resource.name}.conf")
  else
    new_resource.init_file = File.join(node['mongodb']['init_dir'], new_resource.name)
  end

  # TODO(jh): reimplement using polymorphism
  if new_resource.is_replicaset
    if new_resource.replicaset_name
      # trust a predefined replicaset name
      replicaset_name = new_resource.replicaset_name
    elsif new_resource.is_shard && new_resource.shard_name
      # for replicated shards we autogenerate
      # the replicaset name for each shard
      replicaset_name = "rs_#{new_resource.shard_name}"
    else
      # Well shoot, we don't have a predefined name and we aren't
      # really sharded. If we want backwards compatibity, this should be:
      #   replicaset_name = "rs_#{new_resource.shard_name}"
      # which with default values defaults to:
      #   replicaset_name = 'rs_default'
      # But using a non-default shard name when we're creating a default
      # replicaset name seems surprising to me and needlessly arbitrary.
      # So let's use the *default* default in this case:
      replicaset_name = 'rs_default'
    end
  else
    # not a replicaset, so no name
    replicaset_name = nil
  end

  if new_resource.type != "mongos"
    provider = "mongod"
    configserver = nil
  else
    provider = "mongos"
    dbpath = nil
    configserver = new_resource.configserver_nodes.collect{|n| "#{(n['mongodb']['configserver_url'] || n['fqdn'])}:#{n['mongodb']['port']}" }.sort.join(",")
  end
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
    notifies :restart, "service[#{new_resource.name}]"
  end

  # config file
  template new_resource.dbconfig_file do
    cookbook new_resource.template_cookbook
    source new_resource.dbconfig_file_template
    group new_resource.root_group
    owner "root"
    mode "0644"
  end


  # log dir [make sure it exists]
  directory new_resource.logpath do
    owner new_resource.mongodb_user
    group new_resource.mongodb_group
    mode "0755"
    action :create
    recursive true
  end

  if new_resource.type != "mongos"
    # dbpath dir [make sure it exists]
    directory new_resource.dbpath do
      owner new_resource.mongodb_user
      group new_resource.mongodb_group
      mode "0755"
      action :create
      recursive true
    end
  end

  # init script
  template new_resource.init_file do
    cookbook new_resource.template_cookbook
    source new_resource.init_script_template
    group new_resource.root_group
    owner "root"
    mode "0755"
    variables({
        :provides => provider
    })
    notifies :restart, "service[#{new_resource.name}]"
  end

  # service
  service new_resource.name do
    if node['mongodb']['apt_repo'] == "ubuntu-upstart" then
      provider Chef::Provider::Service::Upstart
    end
    supports :status => true, :restart => true
    action new_resource.service_action
    new_resource.service_notifies.each do |service_notify|
      notifies :run, service_notify
    end
    if new_resource.is_replicaset && new_resource.auto_configure_replicaset
      notifies :create, "ruby_block[config_replicaset]"
    end
    if new_resource.type == "mongos" && new_resource.auto_configure_sharding
      notifies :create, "ruby_block[config_sharding]", :immediately
    end
    if new_resource.name == "mongodb"
      # we don't care about a running mongodb service in these cases, all we need is stopping it
      ignore_failure true
    end
  end

  # replicaset
  if new_resource.is_replicaset && new_resource.auto_configure_replicaset
    rs_nodes = search(
      :node,
      "mongodb_cluster_name:#{new_resource.replicaset['mongodb']['cluster_name']} AND \
       mongodb_is_replicaset:true AND \
       mongodb_shard_name:#{new_resource.replicaset['mongodb']['shard_name']} AND \
       chef_environment:#{new_resource.replicaset.chef_environment}"
    )

    ruby_block "config_replicaset" do
      block do
        if not new_resource.replicaset.nil?
          MongoDB.configure_replicaset(new_resource.replicaset, replicaset_name, rs_nodes)
        end
      end
      action :nothing
    end

    ruby_block "run_config_replicaset" do
      block {}
      notifies :create, "ruby_block[config_replicaset]"
    end
  end

  # sharding
  if new_resource.type == "mongos" && new_resource.auto_configure_sharding
    # add all shards
    # configure the sharded collections

    shard_nodes = search(
      :node,
      "mongodb_cluster_name:#{new_resource.cluster_name} AND \
       mongodb_is_shard:true AND \
       chef_environment:#{node.chef_environment}"
    )

    ruby_block "config_sharding" do
      block do
        if new_resource.type == "mongos"
          MongoDB.configure_shards(node, shard_nodes)
          MongoDB.configure_sharded_collections(node, new_resource.sharded_collections)
        end
      end
      action :nothing
    end
  end
end
