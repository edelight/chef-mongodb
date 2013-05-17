#
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

default[:mongodb][:dbpath] = "/var/lib/mongodb"
default[:mongodb][:logpath] = "/var/log/mongodb"
default[:mongodb][:bind_ip] = nil
default[:mongodb][:port] = 27017

# cluster identifier
default[:mongodb][:client_roles] = []
default[:mongodb][:cluster_name] = nil
default[:mongodb][:replicaset_name] = nil
default[:mongodb][:shard_name] = "default"
default[:mongodb][:replicaset_prefix] = "rs_"

default[:mongodb][:auto_configure][:replicaset] = true
default[:mongodb][:auto_configure][:sharding] = true

default[:mongodb][:enable_rest] = false

default[:mongodb][:user] = "mongodb"
default[:mongodb][:group] = "mongodb"
default[:mongodb][:root_group] = "root"

default[:mongodb][:init_dir] = "/etc/init.d"

default[:mongodb][:init_script_template] = "mongodb.init.erb"

# set this to true to use /etc/mongdb.conf instead of command line arguments
default[:mongodb][:use_config_file] = false
# set this to false to stop the cookbook from restarting mongodb when config files change
default[:mongodb][:should_restart_server] = true

case node['platform']
when "freebsd"
  default[:mongodb][:defaults_dir] = "/etc/rc.conf.d"
  default[:mongodb][:init_dir] = "/usr/local/etc/rc.d"
  default[:mongodb][:root_group] = "wheel"
  default[:mongodb][:package_name] = "mongodb"

when "centos","redhat","fedora","amazon","scientific"
  default[:mongodb][:defaults_dir] = "/etc/sysconfig"
  default[:mongodb][:package_name] = "mongo-10gen-server"
  default[:mongodb][:user] = "mongod"
  default[:mongodb][:group] = "mongod"
  default[:mongodb][:init_script_template] = "redhat-mongodb.init.erb"

when "ubuntu"
  default[:mongodb][:defaults_dir] = "/etc/default"
  default[:mongodb][:init_dir] = "/etc/init"
  default[:mongodb][:init_script_template] = "mongodb.upstart.erb"
  default[:mongodb][:root_group] = "root"
  default[:mongodb][:package_name] = "mongodb-10gen"
  default[:mongodb][:apt_repo] = "ubuntu-upstart"

else
  default[:mongodb][:defaults_dir] = "/etc/default"
  default[:mongodb][:root_group] = "root"
  default[:mongodb][:package_name] = "mongodb-10gen"
  default[:mongodb][:apt_repo] = "debian-sysvinit"

end

# whether to load a fresh replicaset or use EBS snapshots
default[:mongodb][:use_ebs_snapshots] = false

# If you're using EBS, piops volume info (only applicable to the raid_data recipe)
default[:mongodb][:use_piops] = true
default[:mongodb][:piops] = 1000
default[:mongodb][:volsize] = 1000
default[:mongodb][:vols] = 2
# set blockdev read ahead to something sane
default[:mongodb][:setra] = 512

# identify the host that will be running backups - override this value in your node or role
default[:mongodb][:backup_host] = nil
