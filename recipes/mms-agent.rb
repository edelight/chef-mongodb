#
# Cookbook Name:: mongodb
# Recipe:: mms-agent
#
# Copyright 2011, Treasure Data, Inc.
#
# All rights reserved - Do Not Redistribute
#
include_recipe 'python'

require 'fileutils'

# munin-node for hardware info
package 'munin-node'

# download
package 'unzip'
remote_file '/tmp/10gen-mms-agent.zip' do
  source 'https://mms.10gen.com/settings/10gen-mms-agent.zip'
end

# unzip
bash 'unzip 10gen-mms-agent' do
  cwd '/tmp/'
  code <<-EOH
    unzip -o -d /usr/local/share/ ./10gen-mms-agent.zip
  EOH
  not_if { File.exist?('/usr/local/share/mms-agent') }
end

# install pymongo
python_pip 'pymongo' do
  action :install
end

# modify settings.py
ruby_block 'modify settings.py' do
  block do
    orig_s = ''
    open('/usr/local/share/mms-agent/settings.py') { |f|
      orig_s = f.read
    }
    s = orig_s
    s = s.gsub(/mms\.10gen\.com/, 'mms.10gen.com')
    s = s.gsub(/@API_KEY@/, node['mongodb']['mms_agent']['api_key'])
    s = s.gsub(/@SECRET_KEY@/, node['mongodb']['mms_agent']['secret_key'])
    if s != orig_s
      open('/usr/local/share/mms-agent/settings.py','w') { |f|
        f.puts(s)
      }
    end
  end
end

# runit
runit_service 'mms-agent' do
  template_name 'mms-agent'
  cookbook 'mms-agent'
  run_restart false
end
