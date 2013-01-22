#
# Cookbook Name:: mongodb
# Recipe:: aws_ebs_volume
#
# Copyright 2012, Applicaster LTD
# Authors:
#       Vitaly Gorodetsky <technical@applicaster.com>
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

return unless node[:cloud] && node[:cloud][:provider] == "ec2"

#For Xen native kernels (used by images such as Ubuntu (official) and Debian) 
#the device is utilized by the kernel of the instance with "xvd" instead of "sd", 
#e.g. attaching as /dev/sdk is accessible on the instance with /dev/xvdk.
if node.filesystem.map { |a| a }.any? { |path| path[0] =~ /\/xv/ }
  node.set[:mongodb][:ebs][:real_volume_connection] = node[:mongodb][:ebs][:volume_connection].gsub('sd','xvd')
else
  node.set[:mongodb][:ebs][:real_volume_connection] = node[:mongodb][:ebs][:volume_connection]
end

#Install right_aws gem
include_recipe "aws"

#Set mongodb db location same as attached ebs volume path
node.set[:mongodb][:dbpath] = node[:mongodb][:ebs][:volume_path]
#Set mongodb logs location to be stored on attached ebs volume
node.set[:mongodb][:logpath] = "#{node[:mongodb][:ebs][:volume_path]}/logs"
#Enable journaling
node.set[:mongodb][:journal] = true

#Load aws credentials from aws data bag
begin
  aws = data_bag_item("aws", "main")
rescue
  Chef::Log.fatal("Follow the instractions on http://community.opscode.com/cookbooks/aws to setup aws data bag")
end

#Create EBS Volume
aws_ebs_volume "db_ebs_volume" do
  aws_access_key aws['aws_access_key_id']
  aws_secret_access_key aws['aws_secret_access_key']
  size node[:mongodb][:ebs][:volume_size]
  device "/dev/#{node[:mongodb][:ebs][:volume_connection]}"
  action [ :create, :attach ]
end

#Format ebs volume as ext4
bash "format_db_ebs_volume" do
  user "root"
  code <<-EOH
  echo ",,L" | sfdisk /dev/#{node[:mongodb][:ebs][:real_volume_connection]}
  echo "y" | mkfs -t ext4 /dev/#{node[:mongodb][:ebs][:real_volume_connection]}1
  EOH
  not_if {File.exists?(node[:mongodb][:ebs][:volume_path])}
end

#Create main folder 
directory "#{node[:mongodb][:ebs][:volume_path]}" do
  owner 'root'
  group 'root'
  action :create
  recursive true
end

#Mount ebs volume
bash "mount_db_ebs_volume" do
  user "root"
  code <<-EOH
  echo `/dev/#{node[:mongodb][:ebs][:real_volume_connection]}1 #{node[:mongodb][:ebs][:volume_path]} auto noatime,noexec,nodiratime 0 0` >> /etc/fstab
  mount -a /dev/#{node[:mongodb][:ebs][:real_volume_connection]}1 #{node[:mongodb][:ebs][:volume_path]}
  EOH
  not_if "df | grep #{node[:mongodb][:ebs][:real_volume_connection]}1"
end

#Create logs folder 
directory "#{node[:mongodb][:ebs][:volume_path]}/logs" do
  owner 'root'
  group 'root'
  action :create
  recursive true
end
