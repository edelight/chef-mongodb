require_relative 'instance'

class Chef
  class Resource::MongodbShardInstance < Resource::MongodbInstance
    def replicaset_name
      if replicaset.nil?
        replicaset_name = nil
      else
        # for replicated shards we autogenerate the replicaset name for each shard
        replicaset_name = "rs_#{replicaset['mongodb']['shard_name']}"
      end
      return replicaset_name
    end
  end
  class Provider::MongodbShardInstance < Provider::MongodbInstance
  end
end
