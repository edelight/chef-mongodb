if node['mongodb']['install_method'] == "10gen" or node.run_list.recipes.include?("mongodb::10gen_repo") then
    include_recipe "mongodb::10gen_repo"
end

# prevent-install defaults, but don't overwrite
file node['mongodb']['sysconfig_file'] do
    content "ENABLE_MONGODB=no"
    group node['mongodb']['root_group']
    owner "root"
    mode 0644
    action :create_if_missing
end

# just-in-case config file drop
template node['mongodb']['dbconfig_file'] do
    cookbook node['mongodb']['template_cookbook']
    source node['mongodb']['dbconfig_file_template']
    group node['mongodb']['root_group']
    owner "root"
    mode 0644
    action :create_if_missing
end

# and we install our own init file
if node['mongodb']['apt_repo'] == "ubuntu-upstart" then
    init_file = File.join(node['mongodb']['init_dir'], "#{node['mongodb']['default_init_name']}.conf")
else
    init_file = File.join(node['mongodb']['init_dir'], "#{node['mongodb']['default_init_name']}")
end
template init_file do
    cookbook node['mongodb']['template_cookbook']
    source node['mongodb']['init_script_template']
    group node['mongodb']['root_group']
    owner "root"
    mode "0755"
    variables({
        :provides => "mongod"
    })
    action :create_if_missing
end

packager_opts = ""
case node['platform_family']
when "debian"
    # this options lets us bypass complaint of pre-existing init file
    # necessary until upstream fixes ENABLE_MONGOD/DB flag
    packager_opts = '-o Dpkg::Options::="--force-confold"'
end

# Create keyFile if specified
if node[:mongodb][:key_file_content] then
  file node[:mongodb][:config][:keyFile] do
    owner node[:mongodb][:user]
    group node[:mongodb][:group]
    mode  "0600"
    backup false
    content node[:mongodb][:key_file_content]
  end
end

# install
package node[:mongodb][:package_name] do
    options packager_opts
    action :install
    version node[:mongodb][:package_version]
end
