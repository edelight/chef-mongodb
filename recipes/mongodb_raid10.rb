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

include_recipe "apt"

dev_mount = "/dev"
ext4 = "ext4"

log_dir     = node[:mongodb][:logpath]  #'/' + node[:mongodb][:mongodb_log]
data_dir    = node[:mongodb][:dbpath]   #'/' + node[:mongodb][:mongodb_data]
journal_dir = node[:mongodb][:journal_path] #'/' + node[:mongodb][:mongodb_journal]



####################  START OF THE RECIPE ##################################

%w( mdadm lvm2).each do |install_pak|
  package install_pak do
    action :install
  end
end

#creating multiple directories
[ log_dir, data_dir, journal_dir ].each do |dir|
  directory dir do
    mode 0775
    owner node[:mongodb][:user]
    group node[:mongodb][:group]
    action :create
    recursive true
  end
end

#this raid the newly attach EBS drives see recipe mongodb_ebs for attach drives and RAID them to RAID 10
mdadm dev_mount + '/'  + node[:mongodb][:ebs_drive_name] do
  devices ["/#{dev_mount}/xvdf1", "/#{dev_mount}/xvdf2", "/#{dev_mount}/xvdf3", "/#{dev_mount}/xvdf4"]
  level node[:mongodb][:raid_config]
  chunk 256
  action [ :create, :assemble]
end

bash "Optimizing EBS Drives for better performance" do
  cwd dev_mount
  code <<-BASH_SCRIPT
  sudo blockdev --setra 128 /#{dev_mount}/#{node[:mongodb][:ebs_drive_name]}
  sudo blockdev --setra 128 /#{dev_mount}/xvdf1
  sudo blockdev --setra 128 /#{dev_mount}/xvdf2
  sudo blockdev --setra 128 /#{dev_mount}/xvdf3
  sudo blockdev --setra 128 /#{dev_mount}/xvdf4
  BASH_SCRIPT
end

bash "Creating Physical Device and Volume Group" do
  cwd dev_mount
  code <<-BASH_SCRIPT
    sudo dd if=/dev/zero of=/#{dev_mount}/#{node[:mongodb][:ebs_drive_name]} bs=512 count=1
    sudo pvcreate /#{dev_mount}/#{node[:mongodb][:ebs_drive_name]}
    sudo vgcreate #{node[:mongodb][:ebs_volume_group_name]} /#{dev_mount}/#{node[:mongodb][:ebs_drive_name]}
  BASH_SCRIPT
end

bash "Creating Logical Volume for Data, Journal and Logs and allocating available storage" do
  cwd dev_mount
  code <<-BASH_SCRIPT
    sudo lvcreate -l 90%vg -n #{node[:mongodb][:mongodb_data]} #{node[:mongodb][:ebs_volume_group_name]}
    sudo lvcreate -l 5%vg -n #{node[:mongodb][:mongodb_log]} #{node[:mongodb][:ebs_volume_group_name]}
    sudo lvcreate -l 5%vg -n #{node[:mongodb][:mongodb_journal]} #{node[:mongodb][:ebs_volume_group_name]}
  BASH_SCRIPT
end

bash "Creating the Log Data Journal Block Devices" do
  code <<-BASH_SCRIPT
  sudo mke2fs -t ext4 -F /#{dev_mount}/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_data]}
  sudo mke2fs -t ext4 -F /#{dev_mount}/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_log]}
  sudo mke2fs -t ext4 -F /#{dev_mount}/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_journal]}
  echo '#{dev_mount}/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_data]} /#{node[:mongodb][:mongodb_data]} #{ext4} defaults,auto,noatime,noexec 0 0' | sudo tee -a /etc/fstab
  echo '#{dev_mount}/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_log]} /#{node[:mongodb][:mongodb_log]} #{ext4} defaults,auto,noatime,noexec 0 0' | sudo tee -a /etc/fstab
  echo '#{dev_mount}/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_journal]} /#{node[:mongodb][:mongodb_journal]} #{ext4} defaults,auto,noatime,noexec 0 0' | sudo tee -a /etc/fstab
  BASH_SCRIPT
end

mount log_dir do
  device "#{dev_mount}/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_log]}"
  fstype ext4
end

mount data_dir do
  device "#{dev_mount}/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_data]}"
  fstype ext4
end

mount journal_dir do
  device "#{dev_mount}/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_journal]}"
  fstype ext4
end

link "/#{node[:mongodb][:mongodb_data]}/#{node[:mongodb][:mongodb_journal]}" do
  to "/#{node[:mongodb][:mongodb_journal]}"
  owner node[:mongodb][:user]
  group node[:mongodb][:group]
end

=begin

ruby_block "Configuring EBS drives to RAID 10 for MongoDB" do

    if node.aws.ebs_volume.db_ebs_volume.has_key?("volume_id")

     create_directories(log_dir, data_dir, journal_dir)
     raid_ebs_drive(dev_mount)
      Mongodb_RAID10.optimize_ebs()
      Mongodb_RAID10.create_physical_drive_volume_group()
      Mongodb_RAID10.create_log_data_journal_volume()
      FileSystem_Config.configure_to_filesystem()
      FileSystem_Config.mount_drives(dev_mount, log_dir, data_dir, journal_dir)
    end
=end
