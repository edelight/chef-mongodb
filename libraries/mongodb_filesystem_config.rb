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

=begin
module FileSystem_Config

  def self.configure_to_filesystem()
    bash "" do
      code <<-BASH_SCRIPT
  sudo mke2fs -t ext4 -F /dev/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_data]}
  sudo mke2fs -t ext4 -F /dev/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_log]}
  sudo mke2fs -t ext4 -F /dev/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_journal]}
  echo '/dev/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_data]} /#{node[:mongodb][:mongodb_data]} ext4 defaults,auto,noatime,noexec 0 0' | sudo tee -a /etc/fstab
  echo '/dev/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_log]} /#{node[:mongodb][:mongodb_log]} ext4 defaults,auto,noatime,noexec 0 0' | sudo tee -a/etc/fstab
  echo '/dev/#{node[:mongodb][:ebs_volume_group_name]}/#{node[:mongodb][:mongodb_journal]} /#{node[:mongodb][:mongodb_journal]} ext4 defaults,auto,noatime,noexec 0 0' | sudo tee -a /etc/fstab
      BASH_SCRIPT
    end
  end

  #mounting the drives for mongodb to use
  def self.mount_drives(log_dir, data_dir, journal_dir)
    ext4 = "ext4"

    mount dev_mount + log_dir do
      device log_dir
      fstype ext4
    end

    mount dev_mount + data_dir do
      device data_dir
      fstype ext4
    end

    mount dev_mount + journal_dir do
      device journal_dir
      fstype ext4
    end

    link "/#{node[:mongod][:mongodb_data]}/#{node[:mongodb][:mongodb_journal]}" do
      to node[:mongodb][:mongodb_journal]
    end
  end


end

=end