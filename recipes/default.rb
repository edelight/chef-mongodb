#
# Cookbook Name:: mongodb
# Recipe:: default
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

case node[:mongodb][:install_method]
when '10gen'
    include_recipe "mongodb::10gen_repo"
end

package node[:mongodb][:package_name] do
  action :install
end

# this is a hack to deal with ubuntu install upstart script
# and because we don't want to maintain more init scripts
if node['platform'] == 'ubuntu' and node['mongodb']['install_method'] == 'package' then
    bash 'remove upstart file' do
        command 'rm /etc/init/mongodb.conf'
        action :run
        only_if 'test -f /etc/init/mongodb.conf'
    end
end
# end hack

needs_mongo_gem = (node.recipe?("mongodb::replicaset") or node.recipe?("mongodb::mongos"))

if needs_mongo_gem
  # install the mongo ruby gem at compile time to make it globally available
  gem_package 'mongo' do
    action :nothing
  end.run_action(:install)
  Gem.clear_paths
end

if node.recipe?("mongodb::default") or node.recipe?("mongodb")
  # configure default instance
  mongodb_instance "mongodb" do
    mongodb_type "mongod"
    bind_ip      node['mongodb']['bind_ip']
    port         node['mongodb']['port']
    logpath      node['mongodb']['logpath']
    dbpath       node['mongodb']['dbpath']
    enable_rest  node['mongodb']['enable_rest']
  end
end
