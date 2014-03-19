chef_major_version = Chef::VERSION.split('.')[0].to_i
chef_minor_version = Chef::VERSION.split('.')[1].to_i
node['mongodb']['gems'].each do |gem, version|
  if chef_major_version < 10 and chef_minor_version < 12
    gem_package g do
      version version
      action :nothing
    end.run_action(:install)
    Gem.clear_paths
  else
    chef_gem g do
      version version
      action :install
    end
  end
end
