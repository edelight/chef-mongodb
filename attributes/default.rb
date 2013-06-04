
# Cookbook Name:: mongodb
# Attributes:: default
#
# Copyright 2010, edelight GmbH
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

default[:mongodb][:user] = "mongodb"
default[:mongodb][:group] = "mongodb"
default[:mongodb][:dbpath]       = "/data/mongodb"
default[:mongodb][:journal_path] = "/data/mongodb/journal" 
default[:mongodb][:port] = 27017
default[:mongodb][:cluster_name] = nil
default[:mongodb][:replicaset_name] = nil
default[:mongodb][:shard_name] = "default"
default[:mongodb][:enable_rest] = false
default[:mongodb][:keep_alive_time] = 300
default[:mongodb][:ulimits] = Array.new

default[:mongodb][:raid] = nil
default[:mongodb][:raid_level] = 10
default[:mongodb][:raid_disk_count] = 4
default[:mongodb][:raid_disk_size] = 4
default[:mongodb][:raid_ebs_type] = "standard"
default[:mongodb][:raid_mount] = "/data"
default[:mongodb][:raid_snaps] = nil
default[:mongodb][:setra] = 128

case node['platform']
when "freebsd"
  default[:mongodb][:defaults_dir] = "/etc/rc.conf.d"
  default[:mongodb][:init_dir] = "/usr/local/etc/rc.d"
  default[:mongodb][:root_group] = "wheel"
else
  default[:mongodb][:defaults_dir] = "/etc/default"
  default[:mongodb][:init_dir] = "/etc/init.d"
  default[:mongodb][:root_group] = "root"
end
