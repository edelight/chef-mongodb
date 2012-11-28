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
require 'chef/provider/directory'

module Mongodb_RAID10

  chef = Chef.new

  chef.resources.dire

  #create the necessary directories that the EBS drives will need
  def self.create_directories(log_dir, data_dir, journal_dir)
    #creating multiple directories
    [ log_dir, data_dir, journal_dir ].each do |dir|
      directory dir do
        mode 0775
        action :create
        recursive true
      end
    end
  end

  #this raid the newly attach EBS drives see recipe mongodb_ebs for attach drives and RAID them to RAID 10
  def self.raid_ebs_drive(dev_mount)
    mdadm dev_mount + node[:mongodb][:ebs_drive_name] do
      devices ["/dev/xvdf1", "/dev/xvdf2", "/dev/xvdf3", "/dev/xvdf4"]
      level node[:mongodb][:raid_config]
      chunk 256
      description "Attaching to instance #{node.ec2.instance_id}"
      action[ :create, :assemble]
    end

  end

  #optimize the EBS drive and device name for better performance
  def self.optimize_ebs()
    bash "Optimizing EBS Drives for better performance" do
      cwd "/dev"
      code <<-BASH_SCRIPT
  sudo blockdev --setra 128 /dev/#{node[:mongodb][:ebs_drive_name]}
  sudo blockdev --setra 128 /dev/xvdf1
  sudo blockdev --setra 128 /dev/xvdf2
  sudo blockdev --setra 128 /dev/xvdf3
  sudo blockdev --setra 128 /dev/xvdf4
      BASH_SCRIPT
    end
  end

  def self.create_physical_drive_volume_group
    bash "Creating Physical Device and Volume Group" do
      cwd "/dev"
      code <<-BASH_SCRIPT
    sudo dd if=/dev/zero of=/dev/#{node[:mongodb][:ebs_drive_name]} bs=512 count=1
    sudo pvcreate /dev/#{node[:mongodb][:ebs_drive_name]}
    sudo vgcreate #{node[:mongodb][:ebs_volume_group_name]} /dev/#{node[:mongodb][:ebs_drive_name]}
      BASH_SCRIPT
    end
  end

  def self.create_log_data_journal_volume()
    bash "Creating Logical Volume for Data, Journal and Logs and allocating available storage" do
      cwd "/dev"
      code <<-BASH_SCRIPT
    sudo lvcreate -l 90%vg -n #{node[:mongodb][:mongodb_data]} #{node[:mongodb][:ebs_volume_group_name]}
    sudo lvcreate -l 5%vg -n #{node[:mongodb][:mongodb_log]} #{node[:mongodb][:ebs_volume_group_name]}
    sudo lvcreate -l 5%vg -n #{node[:mongodb][:mongodb_journal]} #{node[:mongodb][:ebs_volume_group_name]} 
      BASH_SCRIPT
    end
  end

end

=end