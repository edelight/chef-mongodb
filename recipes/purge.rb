
include_recipe "python"

if node['mongodb']['cluster_name'] == 'production_cluster_2' then

   python_pip 'arrow'
   python_pip 'python-daemon'

   region = node[:ec2][:region]
   token = node[:mongodb][:token][region]
   if !node[:mongodb][:purge_window][region].nil?
      when_to_run = node[:mongodb][:purge_window][region]
   end

   template "/etc/init/oldboy.conf" do
     mode "0644"
     owner "root"
     group "root"
     source "purge.upstart.erb"
     variables(
	:when_to_run => when_to_run,
	:token => token
     )
   end

   cookbook_file '/usr/local/bin/oldboy' do
      source 'oldboy'
      owner 'root'
      mode '0755'
      action :create
   end

end
