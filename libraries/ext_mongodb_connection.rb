# extra commands to be included into Mongo::Connection
module ConfigurationCommands
  def initiate_reconfigure(config, opts = {})
    fail MongoArgumentError, 'config must be a document' unless config.class == Hash
    cmd = BSON::OrderedHash.new
    cmd['replSetInitiate'] = config

    # TODO: investigate why this needs to be run on ['admin']
    @db['admin'].command(cmd, command_opts(opts))
  end

  def replicaset_reconfigure(config, opts = {})
    fail MongoArgumentError, 'config must be a document' unless config.class == Hash
    cmd = BSON::OrderedHash.new
    cmd['replSetReconfig'] = config

    # TODO: investigate why this needs to be run on ['admin']
    @db['admin'].command(cmd, command_opts(opts))
  end

  def shard_collection(collection, key, opts = {})
    fail MongoArgumentError, 'collection must be a string' unless collection.class == String
    fail MongoArgumentError, 'key must be a string' unless key.class == String
    cmd = BSON::OrderedHash.new
    cmd['shardcollection'] = collection
    cmd['key'] = { key => 1 }

    @db.command(cmd, command_opts(opts))
  end

  def enable_sharding(db_name, opts = {})
    cmd = BSON::OrderedHash.new
    cmd['enablesharding'] = db_name
    @db.command(cmd, command_opts(opts))
  end
end

module Mongo
  class Connection
    extend ConfigurationCommands
  end
end
