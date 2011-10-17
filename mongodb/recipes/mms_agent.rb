#
# Cookbook Name:: mongodb
# Recipe:: mms_agent
#
# Author:: Nathen Harvey <nharvey@customink.com>
#
# Copyright 2011, CustomInk, LLC
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
include_recipe "python"

python_pip "pymongo" do
  action :install
end

mms_agent_home = node[:mms][:agent_home]
mms_agent_log_directory = node[:mms][:agent_log_dir]
mms_agent_user = node[:mms][:agent_user]

%w(mms_agent_home mms_agent_log_directory).each do |mms_dir|
  directory mms_dir do
    recursive true
  end
end

service "mms_agent" do
  supports [:start,:stop,:status,:restart]
  action   [:start,:enable]
end


%w(README agent.py agentProcess.py blockingStats.py confPull.py logConfig.py mmsAgent.py mongommsinstall.ps1 munin.py nonBlockingStats.py).each do |mms_file|
  cookbook_file "#{mms_agent_home}/#{mms_file}" do
    source mms_file
    mode "0755"
    notifies :restart, resources(:service => "mms_agent"), :delayed
  end
end

template "/usr/local/mms-agent/settings.py" do
  source "settings.py.erb"
  mode "0755"
  notifies :restart, resources(:service => "mms_agent"), :delayed
end

template "/etc/init.d/mms_agent" do
  source "mms_agent.erb"
  owner mms_agent_user
  group mms_agent_user
  mode "0755"
  variables(
    :mms_agent_home => mms_agent_home,
    :mms_agent_user => mms_agent_user,
    :mms_agent_log_directory => mms_agent_log_directory,
    :mms_pid_file => "/var/run/mms_agent.pid",
    :path_to_python => node[:mms][:python_binary]
  )
end

cookbook_file "/etc/logrotate.d/mms_agent_logrotate" do
  source "mms_agent_logrotate"
  owner "root"
  group "root"
  mode "0644"
end