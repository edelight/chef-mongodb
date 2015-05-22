#
# Cookbook Name:: mongodb
# Recipe:: 10gen_repo
#
# Copyright 2011, edelight GmbH
# Authors:
#       Miquel Torres <miquel.torres@edelight.de>
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

# Sets up the repositories for stable mongodb-org packages found here:
# http://www.mongodb.org/downloads#packages
node.override['mongodb']['package_name'] = 'mongodb-org'

case node['platform_family']
when 'debian'
  if node['platform'] == 'ubuntu'
    apt_repository 'mongodb-org-3.0' do
      #code_name = `lsb_release -c`.strip
      uri 'http://repo.mongodb.org/apt/ubuntu'
      distribution "trusty/mongodb-org/3.0"
      components ['multiverse']
      keyserver 'hkp://keyserver.ubuntu.com:80'
      key '7F0CEB10'
      action :add
    end
  end
else
  # pssst build from source
  Chef::Log.warn("Adding the #{node['platform_family']} mongodb-org-3 repository is not yet not supported by this cookbook")
end
