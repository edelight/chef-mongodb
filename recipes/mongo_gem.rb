# The build-essential cookbook was not running during the compile phase, install gcc explicitly for rhel so native
# extensions can be installed

include_recipe 'build-essential'

if platform_family?('rhel')
  sasldev_pkg = 'cyrus-sasl-devel'
else
  sasldev_pkg = 'libsasl2-dev'
end

package sasldev_pkg do
  action :nothing
end.run_action(:install)

node['mongodb']['ruby_gems'].each do |gem, version|
  chef_gem gem do
    version version
  end
end
