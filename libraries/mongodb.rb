#
# Cookbook Name:: mongodb
# Definition:: mongodb
#
# Copyright 2011, edelight GmbH
# Authors:
#       Markus Korn <markus.korn@edelight.de>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# ensure parents exist
class Chef
end
class Chef::ResourceDefinitionList
end

require_relative 'ext_mongodb_connection'
require_relative 'concern_log'

class Chef::ResourceDefinitionList::MongoDB
  include MongoDBCB::LogHelpers

  def self.configure_replicaset(node, name, members)
    if members.length == 0
      warn 'No replicaset member nodes found, defaulting to single node replica set'
    end

    # Ensure the node originating the connection is included in the replicaset
    # convert to a discoteq-style array of service-host-records
    all_members = [members, node].flatten.map do |member|
      ReplicasetMember::ChefNode.new(member).to_h
    end

    # TODO: remove dependency on global node config for port breaks #278
    local_host_record = ReplicasetMember::ChefNode.new(node).to_h

    coord = ReplicationCoordinator.new name, local_host_record, all_members
    coord.configure!
  end

  def self.configure_shards(node, shard_nodes)
    # lazy require, to move loading this modules to runtime of the cookbook
    require 'rubygems'
    require 'mongo'

    # TODO: remove dependency on global node config for port breaks #278
    local_host_record = ReplicasetMember::ChefNode.new(node).to_h

    shard_groups = Hash.new { |h, k| h[k] = [] }

    shard_nodes.each do |n|
      if n['recipes'].include?('mongodb::replicaset')
        # do not include hidden members when calling addShard
        # see https://jira.mongodb.org/browse/SERVER-9882
        next if n['mongodb']['replica_hidden']
        key = "rs_#{n['mongodb']['shard_name']}"
      else
        key = '_single'
      end
      shard_groups[key] << "#{n['fqdn']}:#{n['mongodb']['config']['port']}"
    end
    info shard_groups.inspect

    shard_members = []
    shard_groups.each do |name, members|
      if name == '_single'
        shard_members += members
      else
        shard_members << "#{name}/#{members.join(',')}"
      end
    end
    info shard_members.inspect

    begin
      connection = Mongo::Connection.new(local_host_record['hostname'], local_host_record['port'], :op_timeout => 5)
    rescue => e
      warn "Could not connect to database: '#{local_host_record['hostname']}:#{local_host_record['port']}', reason #{e}"
      return
    end

    admin = connection['admin']

    shard_members.each do |shard|
      cmd = BSON::OrderedHash.new
      cmd['addShard'] = shard
      begin
        result = admin.command(cmd, :check_response => false)
      rescue Mongo::OperationTimeout
        result = "Adding shard '#{shard}' timed out, run the recipe again to check the result"
      end
      info result.inspect
    end
  end

  def self.configure_sharded_collections(node, sharded_collections)
    if sharded_collections.nil? || sharded_collections.empty?
      warn 'No sharded collections configured, doing nothing'
      return
    end

    # lazy require, to move loading this modules to runtime of the cookbook
    require 'rubygems'
    require 'mongo'

    # TODO: remove dependency on global node config for port breaks #278
    local_host_record = ReplicasetMember::ChefNode.new(node).to_h
    connection = make_connection local_host_record

    databases = sharded_collections.keys.map { |x| x.split('.').first }.uniq
    info "enable sharding for these databases: '#{databases.inspect}'"

    databases.each do |db_name|
      begin
        result = connection.enable_sharding db_name, :check_response => false
      rescue Mongo::OperationTimeout
        warn 'Timed out enabling sharding for '\
             "db: #{db_name.inspect}. "\
             'This will take some time, another run should run smoothly.'
        raise
      end
      if ok? result
        # success
        info "Enabled sharding for database '#{db_name}'"
      else
        # some error
        errmsg = result.fetch('errmsg')
        if errmsg == 'already enabled'
          debug "Sharding is already enabled for database '#{db_name}', doing nothing"
        else
          fail "Failed to enable sharding for database #{db_name}, result was: #{result.inspect}"
        end
      end
    end

    sharded_collections.each do |name, key|
      begin
        result = connection.shard_collection name, key, :check_response => false
      rescue Mongo::OperationTimeout
        warn 'Timed out sharding '\
          "collection: #{name.inspect} on key: #{key.inspect}. "\
             'This will take some time, another run should run smoothly.'
        raise
      end
      if ok? result
        # success
        info "Sharding for collection '#{result['collectionsharded']}' enabled"
      else
        # some error
        errmsg = result.fetch('errmsg')
        if errmsg == 'already sharded'
          debug "Sharding is already configured for collection '#{name}', doing nothing"
        else
          fail "Failed to shard collection #{name}, result was: #{result.inspect}"
        end
      end
    end
  end

  ### Connection helpers
  def self.make_connection(hostrecord)
    connection = nil
    rescue_connection_failure do
      connection = Mongo::Connection.new(hostrecord.hostname, hostrecord.port, :op_timeout => 5)
      connection.database_names # check connection
    end
  end

  ### doc predicates
  def ok?(doc)
    Mongo::Support.ok? doc
  end
end
