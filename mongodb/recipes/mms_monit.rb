#
# Cookbook Name:: mongodb
# Recipe:: mms_monit
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

# set-up monit
template "/etc/monit.d/monit_mms_agent" do
  source "monit_mms_agent.erb"
  variables(
    :pid_file => "/var/run/mms_agent.pid",
    :start_program => "/sbin/service mms_agent start",
    :stop_program => "/sbin/service mms_agent stop",
    :max_memory => node[:mms][:monit][:max_memory],
    :max_cpu => node[:mms][:monit][:max_cpu]
  )
  owner "root"
  group "root"
  mode 0755
  notifies :restart, resources(:service => "monit")
end
