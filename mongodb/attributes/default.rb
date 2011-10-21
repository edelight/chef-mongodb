#
# Cookbook Name:: mongodb
# Attributes:: default
#
# Copyright 2010, edelight GmbH
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

default[:mongodb][:dbpath] = "/var/lib/mongodb"
default[:mongodb][:logpath] = "/var/log/mongodb"
default[:mongodb][:port] = 27017

# roles
default[:mongodb][:client_roles] = []
default[:mongodb][:cluster_name] = nil
default[:mongodb][:shard_name] = "default"

# mms-agent
default[:mms][:mms_key] = "MMS_API_KEY"
default[:mms][:secret_key] = "MMS_SECRET_KEY"
default[:mms][:agent_home] = "/usr/local/mms-agent"
default[:mms][:agent_user] = "root"
default[:mms][:agent_log_dir] = "/var/log/mms_agent"
default[:mms][:python_binary] = "/usr/bin/python"
default[:mms][:monit][:max_memory] = "128"
default[:mms][:monit][:max_cpu] = "20"

