#
# Cookbook Name:: mongodb
# Recipe:: mongos
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

include_recipe 'mongodb::install'
include_recipe 'mongodb::mongo_gem'

service node[:mongodb][:default_init_name] do
  action [:disable, :stop]
end

configsrvs = search(
  :node,
  "mongodb_cluster_name:#{node['mongodb']['cluster_name']} AND \
   mongodb_is_configserver:true AND \
   chef_environment:#{node.chef_environment}"
)

if configsrvs.length != 1 && configsrvs.length != 3
  Chef::Log.error("Found #{configsrvs.length} configservers, need either one or three of them")
  fail 'Wrong number of configserver nodes' unless Chef::Config[:solo]
end

mongodb_instance node['mongodb']['mongos']['instance_name'] do
  mongodb_type 'mongos'
  port         node['mongodb']['mongos']['config']['port']
  logpath      node['mongodb']['mongos']['config']['logpath']
  dbpath       node['mongodb']['mongos']['config']['dbpath']
  configservers configsrvs
  enable_rest  node['mongodb']['mongos']['config']['rest']
  smallfiles   node['mongodb']['mongos']['config']['smallfiles']
  config       node['mongodb']['mongos']['config']
end
