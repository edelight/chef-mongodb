maintainer        "edelight GmbH"
maintainer_email  "markus.korn@edelight.de"
license           "Apache 2.0"
description       "Installs and configures mongodb"
version           "0.11"

recipe "mongodb", "Installs and configures a single node mongodb instance"
recipe "mongodb::10gen_repo", "Adds the 10gen repo to get the latest packages"
recipe "mongodb::mongos", "Installs and configures a mongos which can be used in a sharded setup"
recipe "mongodb::configserver", "Installs and configures a configserver for mongodb sharding"
recipe "mongodb::shard", "Installs and configures a single shard"
recipe "mongodb::replicaset", "Installs and configures a mongodb replicaset"
recipe "mongodb::mms_agent", "Installs and configures the MongoDB Monitoring Service agent"
recipe "mongodb::mms_monit", "Adds a monit control file for watching after the MongoDB Monitoring Service agent"

depends "apt"
depends "python"

%w{ ubuntu debian }.each do |os|
  supports os
end

attribute "mongodb/dbpath",
  :display_name => "dbpath",
  :description => "Path to store the mongodb data",
  :default => "/var/lib/mongodb"
  
attribute "mongodb/logpath",
  :display_name => "logpath",
  :description => "Path to store the logfiles of a mongodb instance",
  :default => "/var/log/mongodb"
  
attribute "mongodb/port",
  :display_name => "Port",
  :description => "Port the mongodb instance is running on",
  :default => "27017"
  
attribute "mongodb/client_roles",
  :display_name => "Client Roles",
  :description => "Roles of nodes who need access to the mongodb instance",
  :default => []
  
attribute "mongodb/cluster_name",
  :display_name => "Cluster Name",
  :description => "Name of the mongodb cluster, all nodes of a cluster must have the same name.",
  :default => nil

attribute "mongodb/shard_name",
  :display_name => "Shard name",
  :description => "Name of a mongodb shard",
  :default => "default"  
  
attribute "mongodb/sharded_collections",
  :display_name => "Sharded Collections",
  :description => "collections to shard",
  :default => {}

attribute "mms/mms_key",
  :display_name => "MMS Key",
  :description => "MMS API Key",
  :default => "MMS_API_KEY"
  
attribute "mms/secret_key",
  :display_name => "MMS Secret Key",
  :description => "MMS Secret Key",
  :default => "MMS_SECRET_KEY"

attribute "mms/agent_home",
  :display_name => "MMS Agent Home",
  :description => "The location to install the agent",
  :default => "/usr/local/mms-agent"

attribute "mms/agent_user",
  :display_name => "MMS Agent User",
  :description => "The user to run the MMS agent",
  :default => "root"

attribute "mms/agent_log_dir",
  :display_name => "MMS Agent Log Directory",
  :description => "The directory for the mms_agent log",
  :default => "/var/log/mms_agent"

attribute "mms/python_binary",
  :display_name => "Python binary",
  :description => "The python binary when running the agent",
  :default => "/usr/bin/python"

attribute "mms/monit/max_memory",
  :display_name => "MMS Agent Maximum Memory",
  :description => "The maximum amount of memory (MB) that monit will allow before restarting the agent",
  :default => "128"

attribute "mms/monit/max_cpu",
  :display_name => "MMS Agent Maximum CPU",
  :description => "The maximum CPU percentage that monit will allow before restarting the agent",
  :default => "20"
