# All the configuration files that can be dumped
# the attribute-based-configuration
# dump anything into default['mongodb']['config'][<setting>] = <value>
# these options are in the order of mongodb docs

include_attribute 'mongodb::default'

default['mongodb']['config']['port'] = node['mongodb']['port'] || 27017
default['mongodb']['config']['bind_ip'] = node['mongodb']['bind_ip'] || '0.0.0.0'
default['mongodb']['config']['logpath'] = File.join(node['mongodb']['logpath'] || '/var/log/mongodb', 'mongodb.log')
default['mongodb']['config']['logappend'] = true
# The platform_family? syntax in attributes files was added in Chef 11
# if node.platform_family?("rhel", "fedora") then
case node['platform_family']
when 'rhel', 'fedora'
    default['mongodb']['config']['fork'] = true
else
  default['mongodb']['config']['fork'] = false
end
default['mongodb']['config']['dbpath'] = node['mongodb']['dbpath'] || '/var/lib/mongodb'
default['mongodb']['config']['nojournal'] = node['mongodb']['nojournal'] || false
default['mongodb']['config']['rest'] = node['mongodb']['enable_rest'] || false
default['mongodb']['config']['smallfiles'] = node['mongodb']['smallfiles'] || false
default['mongodb']['config']['oplogSize'] = node['mongodb']['oplog_size'] || nil

default['mongodb']['config']['replSet'] = node['mongodb']['replicaset_name'] || nil
default['mongodb']['config']['keyFile'] = '/etc/mongodb.key' if node['mongodb']['key_file']
