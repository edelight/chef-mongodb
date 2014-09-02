# Defaults for mongod.conf
#
# Options are in order of the default mongod.conf

include_attribute 'mongodb::default'

default['mongod']['config']['port']           = 27017
default['mongod']['config']['bind_ip']        = '127.0.0.1'
default['mongod']['config']['logpath']        = '/var/log/mongodb/mongod.log'
default['mongod']['config']['logappend']      = true
default['mongod']['config']['nojournal']      = false
default['mongod']['config']['cpu']            = false
default['mongod']['config']['noauth']         = true
default['mongod']['config']['auth']           = false
default['mongod']['config']['verbose']        = false
default['mongod']['config']['objcheck']       = false
default['mongod']['config']['quota']          = false
default['mongod']['config']['diaglog']        = 0
default['mongod']['config']['nohints']        = false
default['mongod']['config']['httpinterface']  = false
default['mongod']['config']['noscripting']    = false
default['mongod']['config']['notablescan']    = false
default['mongod']['config']['noprealloc']     = false

default['mongod']['config']['oplogSize']      = nil
default['mongod']['config']['replSet']        = nil
default['mongod']['config']['keyFile']        = '/etc/mongodb.key' if node['mongodb']['key_file_content']
