#
# Cookbook Name:: mongodb
# Recipe:: shard
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

if node[:cloud] and 
   node[:cloud][:provider] == 'ec2' and
   node[:mongodb][:raid] then

   include_recipe 'aws'

   if node[:mongodb][:raid_ebs_type] == 'io1' then
      aws_ebs_raid "data_raid" do
	 level node[:mongodb][:raid_level]
	 disk_count node[:mongodb][:raid_disk_count]
	 disk_size node[:mongodb][:raid_disk_size]
	 disk_type node[:mongodb][:raid_ebs_type]
	 disk_piops node[:mongodb][:raid_ebs_piops]
	 mount_point node[:mongodb][:raid_mount]
	 snapshots node[:mongodb][:raid_snaps]
	 filesystem node[:mongodb][:raid_fs]
	 filesystem_options node[:mongodb][:raid_fs_opts]
	 action [ :auto_attach ]
      end
   else
      aws_ebs_raid "data_raid" do
	 level node[:mongodb][:raid_level]
	 disk_count node[:mongodb][:raid_disk_count]
	 disk_size node[:mongodb][:raid_disk_size]
	 disk_type node[:mongodb][:raid_ebs_type]
	 mount_point node[:mongodb][:raid_mount]
	 snapshots node[:mongodb][:raid_snaps]
	 filesystem node[:mongodb][:raid_fs]
	 filesystem_options node[:mongodb][:raid_fs_opts]
	 action [ :auto_attach ]
      end
   end

   # setup raid mount in fstab
   Chef::Log.info("Adding mount info to fstab for raid device.")
   mount node[:mongodb][:raid_mount] do
      device lazy { 
	 "/dev/#{node[:aws][:raid][node[:mongodb][:raid_mount]][:raid_dev]}"
      }
      fstype node[:mongodb][:raid_fs]
      options node[:mongodb][:raid_fs_opts]
      action [:enable]
   end

   if node[:mongodb][:encfs] then
      include_recipe 'tealium_encfs'

      tealium_encfs_mount node[:mongodb][:data_root] do
         encrypted_data node[:mongodb][:raid_mount]
	 fuse_opts 'noatime'
      end
   end

end

include_recipe "mongodb::default"

# disable and stop the default mongodb instance
service "mongodb" do
  supports :status => true, :restart => true
  action [:disable, :stop]
end

is_replicated = node[:recipes].include?("mongodb::replicaset")


# we are not starting the shard service with the --shardsvr
# commandline option because right now this only changes the port it's
# running on, and we are overwriting this port anyway.
mongodb_instance "mongodb_shard" do
  mongodb_type "shard"
  port         node[:mongodb][:port]
  dbpath       node[:mongodb][:dbpath]
  if is_replicated
    replicaset    node
  end
  enable_rest node[:mongodb][:enable_rest]
end
