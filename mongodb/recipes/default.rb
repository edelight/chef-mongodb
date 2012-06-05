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

case node['platform']
when "debian", "ubuntu"
  package "mongodb" do
    action :install
  end
when "redhat", "centos", "fedora"
  package "mongo-10gen" do
    action :install
  end
  package "mongo-10gen-server" do
    action :install
  end
end

needs_mongo_gem = (node.recipes.include?("mongodb::replicaset") or node.recipes.include?("mongodb::mongos"))

if needs_mongo_gem
  # install the mongo ruby gem at compile time to make it globally available
  gem_package 'mongo' do
    action :nothing
  end.run_action(:install)
  Gem.clear_paths
end

if node.recipes.include?("mongodb::default") or node.recipes.include?("mongodb")
  name = case platform
         when "centos", "redhat", "fedora"
           "mongod"
         when "ubuntu", "debian"
           "mongodb"
         end

  # configure default instance
  mongodb_instance name do
    mongodb_type "mongod"
    port         node['mongodb']['port']
    logpath      node['mongodb']['logpath']
    dbpath       node['mongodb']['dbpath']
  end
end
