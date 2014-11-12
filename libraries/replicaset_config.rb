#
# Cookbook Name:: mongodb
# Definition:: mongodb
#
# Copyright 2013, Joseph Holsten
# Authors:
#       Joseph Anthony Pasquale Holsten <joseph@joesphholsten.com
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
require_relative 'replicaset_member'

module MongoDBCB
  # support class to convert a node object into a mongodb replicaset member document
  class ReplicasetConfig
    attr_accessor :id, :members, :version

    def initialize(id, members = {}, version = 1)
      @id = id
      @members = members
      @version = version
    end

    def self.from_config(cfg)
      new(cfg['_id'], cfg['members'], cfg['version'])
    end

    def <<(member)
      member.id ||= max_id
      members[member.host] = member
    end

    def to_doc
      {
        '_id' => id,
        'version' => version,
        'members' => member_list
      }
    end

    def member_list
      # sort by name to ensure member ids are the same between runs
      members.sort.map { |m| m[1].to_h }
    end

    def matches?(config)
      config['_id'] == id &&
      config['members'] == member_list
    end

    def matches_by_ipaddress?(config)
      config['_id'] == id &&
      config['members'] == member_list_with_ipaddresses
    end

    def inspect
      '<ReplicasetConfig ' \
      "id=#{id.inspect} " \
      "members=\"#{members.values.map { |m| m.host }.join(', ')}\" "\
      "version=#{version.inspect}>"
    end

    def incr
      self.version += 1
    end

    def max_id
      members.map { |_, m| m.id }.max
    end

    def replace_member_hosts_with_fqdns_from(config)
      self.members = config.members.dup
    end

    def remove_members_absent_from(config)
      expected_hosts = config.member_list.map(&:host)
      members.delete_if { |host, _| !expected_hosts.include?(host) }
    end

    def update_member_attributes_while_keeping_ids_from(config)
      members.each do |host, current_member|
        intended_member = config.members[host].dup
        intended_member.id = current_member.id
        members[host] = intended_member
      end
    end

    def add_members_adjuct_to(config)
      config.members.each do |host, member|
        next unless members.key? host
        self << member
      end
    end

    def ==(other)
      self.id == other.id &&
      self.version == other.version &&
      self.member_list == other.member_list
    end

    private

    def member_list_with_ipaddresses
      # sort by name to ensure member ids are the same between runs
      members.sort.map { |m| m[1].to_h_with_ipaddress }
    end
  end
end
