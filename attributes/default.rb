
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
default[:mongodb][:data_root] = "/data"
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
default[:mongodb][:raid_ebs_piops] = 100
default[:mongodb][:raid_mount] = "/data"
default[:mongodb][:raid_snaps] = nil
default[:mongodb][:raid_fs] = "ext4"
default[:mongodb][:raid_fs_opts] = "rw,noatime,nodiratime,nobarrier"
default[:mongodb][:setra] = 128

default[:mongodb][:encfs] = nil

default[:mongodb][:backup][:hour] = "5"
default[:mongodb][:backup][:minute] = "15"
default[:mongodb][:backup][:archive_days] = "30"

default[:mongodb][:token]['us-west-1'] = 11000000
default[:mongodb][:token]['us-east-1'] = 21000000
default[:mongodb][:token]['eu-west-1'] = 31000000

# All times UTC
default[:mongodb][:purge_window]['us-west-1'] = '03:00-13:00'
default[:mongodb][:purge_window]['us-east-1'] = '00:00-10:00'
default[:mongodb][:purge_window]['eu-west-1'] = '19:00-05:00'

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
