#
# Cookbook Name:: mongodb
# Provider:: user 
#
# Authors:
#       BK Box <bk@theboxes.org>
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

action :add do
  unless Chef::MongoDB.user_exists?(node, new_resource.name, new_resource.password, new_resource.database)
    Chef::MongoDB.configure_user(node, new_resource.name, new_resource.password, new_resource.database)
  end
end

action :delete do
  Chef::MongoDB.configure_user(node, new_resource.name, new_resource.password, new_resource.database, :delete => true)
end

action :update do
  Chef::MongoDB.configure_user(node, new_resource.name, new_resource.password, new_resource.database)
end
