#
# Copyright 2014, Joseph Holsten
# Authors:
#       Joseph Anthony Pasquale Holsten <joseph@josephholsten.com>
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

require 'json'
require_relative 'ext_boolean'

module MongoDBCB
  # ReplicasetMember is a simple struct to represent
  # each node in a MongoDB replicaset member document
  ReplicasetMember = Struct.new(
      :id,
      :hostname,
      :ipaddress,
      :port,
      :slave_delay,
      :votes,
      :arbiter_only,
      :build_indexes,
      :hidden,
      :tags,
      :priority
    ) do

    # Returns a ReplicasetMember with the following defaults:
    #
    #   port:          27107
    #   slaveDelay:    0
    #   votes:         1
    #   priority:      1
    #   arbiter_only:  false
    #   build_indexes: true
    #   hidden:        false
    #   tags:          {}
    def self.default
      @default ||= new(
        'port' => 27107,
        'slaveDelay' => 0,
        'votes' => 1,
        'priority' => 1,
        'arbiter_only' => false,
        'build_indexes' => true,
        'hidden' => false,
        'tags' => {}
      )
    end

    def initialize(hash, id = nil)
      fail ArgumentError, 'hash must contain a hostname' unless hash['hostname']
      self.id = id
      self.hostname = hash['hostname']
      self.ipaddress = hash['ipaddress']
      # Integer
      self.port = hash['port'] ? Integer(hash['port']) : 27017
      self.slave_delay = hash['slave_delay'] ? Integer(hash['slave_delay']) : 0
      self.votes = hash['votes'] ? Integer(hash['votes']) : 1
      # Boolean
      self.arbiter_only = hash['arbiter_only'].nil? ? false : Boolean(hash['arbiter_only'])
      self.build_indexes = hash['build_indexes'].nil? ? true : Boolean(hash['build_indexes'])
      self.hidden = hash['hidden'].nil? ? false : Boolean(hash['hidden'])
      # Hash
      self.tags = hash['tags'] ? hash['tags'].to_hash : {}

      # priority must be 0 if the member lacks buildIndexes, is hidden or
      # has slaveDelay
      if !build_indexes? || hidden? || slave_delay
        # must not become primary
        self.priority = 0
      else
        self.priority = hash['priority'] ? Integer(hash['priority']) : 1
      end
    end

    def fqdn_host
      "#{hostname}:#{port}"
    end

    def ipaddress_host
      "#{ipaddress}:#{port}"
    end

    alias_method :arbiter_only?, :arbiter_only
    alias_method :hidden?, :hidden
    alias_method :build_indexes?, :build_indexes
    alias_method :host, :fqdn_host

    def to_h
      hash = {
        'host' =>          fqdn_host,
        'arbiterOnly' =>   arbiter_only?,
        'buildIndexes' =>  build_indexes?,
        'hidden' =>        hidden?,
        'slaveDelay' =>    slave_delay,
        'priority' =>      priority,
        'tags' =>          tags,
        'votes' =>         votes
      }
      hash['_id'] = id if id
      hash
    end

    def to_h_with_ipaddress
      hash = {
        'host' =>          ipaddress_host
      }
      hash['_id'] = id if id
      hash
    end

    def <=>(other)
      if other.respond_to :host
        host <=> other.host
      else
        nil
      end
    end
  end unless defined?(ReplicasetMember)
end

# ReplicasetMember is a support class to convert a node object into a
# MongoDB replicaset member document.
#
# This implementation maps document keys onto values from the node
# object, and requires each to exist:
#
#    host:          "{node.fqdn}:{node.mongodb.config.port}"
#    arbiterOnly:   node.mongodb.replica_arbiter_only
#    buildIndexes:  node.mongodb.replica_build_indexes
#    hidden:        node.mongodb.replica_hidden
#    slaveDelay:    node.mongodb.replica_slave_delay
#    priority:      node.mongodb.replica_priority
#    tags:          node.mongodb.replica_tags
#    votes:         node.mongodb.replica_votes
class MongoDBCB::ReplicasetMember::ChefNode
  attr_accessor :node

  def self.load(node)
    new(node).to_h
  end

  def initialize(node)
    @node = node
  end

  # This is the simplest mapping that could possibly work. All
  # real validation and helpers happen in ReplicasetMember.
  def to_h
    {
      'hostname' =>       node['fqdn'],
      'port' =>           mongodb['config']['port'],
      'arbiter_only' =>   mongodb['replica_arbiter_only'],
      'build_indexes' =>  mongodb['replica_build_indexes'],
      'hidden' =>         mongodb['replica_hidden'],
      'slave_delay' =>    mongodb['replica_slave_delay'],
      'priority' =>       mongodb['replica_priority'],
      'tags' =>           mongodb['replica_tags'],
      'votes' =>          mongodb['replica_votes'],
      'ipaddress' =>      node['ipaddress']
    }
  end

  private

  def mongodb
    node['mongodb']
  end
end

