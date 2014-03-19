#
# Cookbook Name:: mongodb
# Recipe:: mms-agent
#
# Copyright 2011, Treasure Data, Inc.
#
# All rights reserved - Do Not Redistribute
#

require 'fileutils'
include_recipe 'python'
include_recipe 'mongodb::mongo_gem'

# munin-node for hardware info
package node['mongodb']['mms_agent']['munin_package'] do
  action :install
  only_if { node['mongodb']['mms_agent']['install_munin'] }
end

# python dependencies
python_pip 'pymongo' do
    version node['mongodb']['mms_agent']['pymongo_version']
    action :install
end

# download, and unzip if it's changed
package 'unzip'
remote_file "#{Chef::Config[:file_cache_path]}/mms-monitoring-agent.zip" do
  source node['mongodb']['mms_agent']['install_url']
  # irrelevant because of https://jira.mongodb.org/browse/MMS-1495
  checksum node['mongodb']['mms_agent']['checksum'] if node['mongodb']['mms_agent'].key?(:checksum)
  notifies :run, 'bash[unzip mms-monitoring-agent]', :immediately
end

directory "#{Pathname.new(node['mongodb']['mms_agent']['install_dir']).parent}" do
  recursive true
end

bash 'unzip mms-monitoring-agent' do
  code <<-EOS
    rm -rf #{node['mongodb']['mms_agent']['install_dir']}
    unzip -o -d #{Pathname.new(node['mongodb']['mms_agent']['install_dir']).parent} #{Chef::Config[:file_cache_path]}/mms-monitoring-agent.zip"
  EOS
  action :nothing
  only_if do
    def checksum_zip_contents(zipfile)
      require 'zip/filesystem'
      require 'digest'

      files = Zip::File.open(zipfile).collect.reject { |f| f.name_is_directory? }.sort
      content = files.map { |f| f.get_input_stream.read }.join
      Digest::SHA256.hexdigest content
    end
    new_checksum = checksum_zip_contents("#{Chef::Config[:file_cache_path]}/mms-monitoring-agent.zip")
    existing_checksum = node['mongodb']['mms_agent'].key?(:checksum) ? node['mongodb']['mms_agent']['checksum'] : 'NONE'
    Chef::Log.debug "new checksum = #{new_checksum}, expected = #{existing_checksum}"

    should_install = !File.exist?("#{node['mongodb']['mms_agent']['install_dir']}/settings.py") || new_checksum != existing_checksum
    # update the expected checksum in chef, for reference
    node.set['mongodb']['mms_agent']['checksum'] = new_checksum
    should_install
  end
end

# runit and agent logging
directory node['mongodb']['mms_agent']['log_dir'] do
  action :create
  recursive true
end

include_recipe 'runit::default'
mms_agent_service = runit_service 'mms-agent' do
  template_name 'mms-agent'
  cookbook 'mongodb'
  options(
    :mms_agent_install_dir => node['mongosb']['mms_agent']['install_dir'],
    :mms_agent_log_dir => node['mongodb']['mms_agent']['log_dir']
  )
  action :nothing
end

# update settings.py and restart the agent if there were any key changes
ruby_block 'modify settings.py' do
  block do
    Chef::Log.warn 'Found empty mms_agent.api_key attribute' if node['mongodb']['mms_agent']['api_key'].empty?

    orig_s = ''
    open("#{node['mongodb']['mms_agent']['install_dir']}/settings.py") do |f|
      orig_s = f.read
    end
    s = orig_s
    s = s.gsub(/@MMS_SERVER@/, "#{node['mongodb']['mms_agent']['mms_server']}")
    s = s.gsub(/@API_KEY@/, "#{node['mongodb']['mms_agent']['api_key']}")
    # python uses True/False not true/false
    s = s.gsub(/enableMunin = .*/, "enableMunin = #{node['mongodb']['mms_agent']['enable_munin'] ? "True" : "False"}")
    s = s.gsub(/@DEFAULT_REQUIRE_VALID_SERVER_CERTIFICATES@/, "#{node['mongodb']['mms_agent']['require_valid_server_cert'] ? "True" : "False"}")

    if s != orig_s
      Chef::Log.debug 'Settings changed, overwriting and restarting service'
      open("#{node['mongodb']['mms_agent']['install_dir']}/settings.py", 'w') do |f|
        f.puts(s)
      end

      # update the agent version in chef, for reference
      mms_agent_version = /settingsAgentVersion = "(.*)"/.match(s)[1]
      node['mongodb']['mms_agent']['version']= mms_agent_version

      notifies :enable, mms_agent_service, :delayed
      notifies :restart, mms_agent_service, :delayed
    end
  end
end
