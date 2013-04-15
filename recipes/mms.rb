include_recipe 'python::virtualenv'

package 'unzip'

remote_file "#{Chef::Config[:file_cache_path]}/10gen-mms-agent.zip" do
    source node[:mongodb][:mms_source]
end

python_virtualenv '/var/lib/mms' do
    action :create
end

bash "unzip 10gen-mms-agent" do
    cwd Chef::Config[:file_cache_path]
    code <<-EOH
        unzip -o -d #{node[:mongodb][:mms_dir]} 10gen-mms-agent.zip
    EOH
    not_if { File.exists? "#{node[:mongodb][:mms_dir]}/mms-agent" }
end

template "mms-agent.conf" do
    action :create
    path "/etc/init/mms-agent.conf"
    source "mms-agent.upstart.erb"
    group node['mongodb']['root_group']
    owner "root"
    mode "0644"
    variables :dir => node[:mongodb][:mms_dir], :user => node[:mongodb][:user], :group => node[:mongodb][:group]
end

service "mms-agent" do
    provider Chef::Provider::Service::Upstart
    supports :status => true, :restart => true
    action [:enable, :start]
    subscribes :restart, resources(:template => "mms-agent.conf")
end
