name              'mongodb'
maintainer        'edelight GmbH'
maintainer_email  'markus.korn@edelight.de'
license           'Apache 2.0'
description       'Installs and configures mongodb'
version           '0.15.0'

recipe 'mongodb', 'Installs and configures a single node mongodb instance'
recipe 'mongodb::10gen_repo', 'Adds the 10gen repo to get the latest packages'
recipe 'mongodb::mongos', 'Installs and configures a mongos which can be used in a sharded setup'
recipe 'mongodb::configserver', 'Installs and configures a configserver for mongodb sharding'
recipe 'mongodb::shard', 'Installs and configures a single shard'
recipe 'mongodb::replicaset', 'Installs and configures a mongodb replicaset'
recipe 'mongodb::mms-agent', 'Installs and configures a Mongo Management Service agent'

depends 'apt', '>= 1.8.2'
depends 'python', '>= 1.3.0'
depends 'runit', '>= 1.1.6'
depends 'yum', '< 3.0.0'

%w{ ubuntu debian freebsd centos redhat fedora amazon scientific}.each do |os|
  supports os
end

attribute 'mongodb/config/dbpath',
          :display_name => 'dbpath',
          :description => 'Path to store the mongodb data',
          :default => '/var/lib/mongodb'

attribute 'mongodb/config/logpath',
          :display_name => 'logpath',
          :description => 'Path to store the logfiles of a mongodb instance',
          :default => '/var/log/mongodb/mongodb.log'

attribute 'mongodb/config/port',
          :display_name => 'Port',
          :description => 'Port the mongodb instance is running on',
          :default => '27017'

attribute 'mongodb/reload_action',
          :display_name => 'Reload',
          :description => 'Action to take when MongoDB config files are modified',
          :default => 'restart'

attribute 'mongodb/client_roles',
          :display_name => 'Client Roles',
          :description => 'Roles of nodes who need access to the mongodb instance',
          :type => 'array',
          :default => []

attribute 'mongodb/cluster_name',
          :display_name => 'Cluster Name',
          :description => 'Name of the mongodb cluster, all nodes of a cluster must have the same name.',
          :default => nil

attribute 'mongodb/shard_name',
          :display_name => 'Shard name',
          :description => 'Name of a mongodb shard',
          :default => 'default'

attribute 'mongodb/sharded_collections',
          :display_name => 'Sharded Collections',
          :description => 'collections to shard',
          :type => 'array',
          :default => []

attribute 'mongodb/config/replSet',
          :display_name => 'Replicaset Name',
          :description => 'Name of a mongodb replicaset',
          :default => nil

attribute 'mongodb/config/rest',
          :display_name => 'Enable Rest',
          :description => 'Enable the ReST interface of the webserver'

attribute 'mongodb/config/smallfiles',
          :display_name => 'Use small files',
          :description => 'Modify MongoDB to use a smaller default data file size'

attribute 'mongodb/config/bind_ip',
          :display_name => 'Bind address',
          :description => 'MongoDB instance bind address',
          :default => nil

attribute 'mongodb/package_version',
          :display_name => 'MongoDB package version',
          :description => 'Version of the MongoDB package to install',
          :default => nil

attribute 'mongodb/configfile',
          :display_name => 'Configuration File',
          :description => 'Name of configuration file to use with when starting mongod/mongos vs command line options',
          :default => nil

attribute 'mongodb/config/nojournal',
          :display_name => 'Disable Journals',
          :description => 'Journals are enabled by default on 64bit after mongo 2.0, this can disable it',
          :default => 'false'

attribute 'mongodb/mms_agent',
          :display_name => 'MMS Agent',
          :description => 'Hash of MMS Agent attributes',
          :type => 'hash'

attribute 'mongodb/mms_agent/api_key',
          :display_name => 'MMS Agent API Key'

attribute 'mongodb/mms_agent/mm_server',
          :display_name => 'MMS Server'

attribute 'mongodb/mms_agent/require_valid_server_cert',
          :display_name => 'Require valid certificate from server'

attribute 'mongodb/oplog_size',
          :display_name => 'oplogSize',
          :description => 'Specifies a maximum size in megabytes for the replication operation log',
          :default => nil
