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

include_recipe "mongodb"

if ::File.executable?('/etc/init.d/mongodb') then
   service "mongodb" do
     supports :status => true, :restart => true
     action [:disable, :stop]
   end
end

configsvr = search(
  :node,
  "mongodb_cluster_name:#{node['mongodb']['cluster_name']} AND \
   recipes:mongodb\\:\\:configserver AND \
   chef_environment:#{node.chef_environment}"
)

Chef::Log.info( "Searching for Mongo Config Servers -- search result is: #{configsvr}" )

if configsvr.length != 1 and configsvr.length != 3
  Chef::Log.error("Found #{configsvr.length} configserver, need either one or three of them")
  raise "Wrong number of configserver nodes"
end

mongodb_instance "mongos" do
  mongodb_type "mongos"
  port         node['mongodb']['port']
  dbpath       node['mongodb']['dbpath']
  configserver configsvr
  enable_rest  node['mongodb']['enable_rest']
end
