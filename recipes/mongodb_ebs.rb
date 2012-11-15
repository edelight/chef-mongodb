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

include_recipe "mongodb"
include_recipe "aws"

app_environment = node["app_environment"] || "development"

aws = search(:aws,"id:#{app_environment}").first

for i in 1..node[:mongodb][:number_ebs_drives] do
  aws_ebs_volume "db_ebs_volume" do
    aws_access_key aws['aws_access_key_id']
    aws_secret_access_key aws['aws_secret_access_key']
    size node[:mongodb][:ebs_size]
    device "/dev/sdf#{i}"
    action [ :create, :attach ]
    description "Attaching to instance #{node.ec2.instance_id}"
  end
end

