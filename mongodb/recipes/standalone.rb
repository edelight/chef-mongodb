#
# Cookbook Name:: mongodb
# Recipe:: default
#
# Copyright 2012, Riot Games
# Authors:
#       Trotter Cashion <trotter@mashion.net>
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
include_recipe "riot-mongodb"

name = case node['platform']
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
