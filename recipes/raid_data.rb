include_recipe "aws"

gem_package "aws-sdk" do
  version "1.3.5"
  action :nothing
end.run_action(:install)
Gem.clear_paths

if node[:mongodb][:use_piops]
  create_raided_drives_from_snapshot do
    disk_counts node[:mongodb][:vols].to_i
    disk_size node[:mongodb][:volsize].to_i
    disk_type 'io1'
    disk_piops node[:mongodb][:piops].to_i
    level 0
    filesystem "ext4"
  end
else
  create_raided_drives_from_snapshot do
    disk_counts node[:mongodb][:vols].to_i
    disk_size node[:mongodb][:volsize].to_i
    level 0
    filesystem "ext4"
  end
end

ENV['mongodir'] = node[:mongodb][:dbpath]
script "update_permissions" do
  interpreter "bash"
  user "root"
  code <<-EOH
    chown -R #{node[:mongodb][:user]}.#{node[:mongodb][:group]} $mongodir
  EOH
end

script "add_array_to_mdadm" do
  interpreter "bash"
  user "root"
  code "mdadm --detail --scan >> /etc/mdadm/mdadm.conf"
  not_if "grep ^ARRAY /etc/mdadm/mdadm.conf"
end

