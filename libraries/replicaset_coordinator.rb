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

require 'mongo'

require_relative 'ext_mongodb_connection'
require_relative 'concern_log'
require_relative 'replicaset_config'
require_relative 'replicaset_member'

module MongoDBCB
  # ReplicationCoordinator manages all the actions involved in
  # configuring a replicaset, be it initializing it from scratch,
  # updating it with new members, or verifying the
  # current configuration.
  class ReplicasetCoordinator
    include ::MongoDBCB::LogHelpers
    attr_reader :name, :service_host_records, :local_host_record

    # A ReplicasetCoordinator requires three things:
    # - a name, which is the identifier of the replicaset
    # - a local host record, containing at least 'hostname' and 'port' attributes
    # - a service host record list, which is an array of host records for each intended member of the replicaset
    #
    # A host record is just a map of attributes for each host,
    # including at least a 'hostname' key
    def initialize(name, local_host_record, service_host_records)

      fail ArgumentError, 'No replicaset member host records provided' if service_host_records.length == 0

      @name = name
      @local_host_record = local_host_record
      @service_host_records = service_host_records
    end

    def replicaset_config
      # this is generated from immutable attributes, so we can cache this value
      @replicaset_config ||= begin
        # ReplicasetConfig prevents duplication, no need to check for existance
        replicaset_config = ReplicasetConfig.new name
        service_host_records.each do |r|
          replicaset_config << ReplicasetMember.new(r)
        end
        replicaset_config
      end
    end

    def configure!
      # Configuring replication idempotently is complex, and may
      # involve attempting a number of approaches and recovering to
      # continue. At the moment this implementation encapsulates quite
      # a bit of knowledge which cannot be broken up.
      #
      # You'll notice every network request is proceeded by an info
      # message, returns by a debug message, and exception rethrows
      # with a warn message. So yes, between the logging and the
      # comments, this is an obscene amount of documentation.
      #
      # You're welcome.
      debug "Configuring replicaset: #{name.inspect} "\
            "with config: #{replicaset_config.inspect}"
      # We begin by attempting to initialize replication.
      result = nil
      begin
        info 'Initiating replicaset'
        result = slave_connection!.initiate_replicaset replicaset_config.to_doc, :check_response => false
      # Replicaset initialization is often a slow process and may time
      # out, but while not exceptional is not necessarily recoverable
      rescue Mongo::OperationTimeout
        # TODO: investigate ways to recover here
        warn 'Timed out initiating the replicaset. This will take '\
             'some time, another run should run smoothly.'
        raise
      end

      # If replication initialized successfully, we're satisfied.
      if ok? result
        debug 'Replicaset sucessfully initialized'
        return
      end

      # If replication could not be initialized because it's already
      # initialized, then we need to find out how to proceed.
      if (host_record = already_initialized_err?(result))
        current_config = current_replicaset_config! :from => host_record
        # First we need to understand if the current config is
        # different from our goal.
        if replicaset_config.matches? current_config
          # If the current config matches our goal, then
          # we're satisfied.
          debug "Replicaset #{name.inspect} already configured"
          return
        else
          # When the current config differs, then we'll need to update
          # the config.
          intended_config = current_config
          intended_config.incr
          if replicaset_config.matches_by_ipaddress? config
            # When the config is up-to-date but ips are used instead of
            # hostnames, we need merely to change the host values to
            # the hostnames which match how they are provided to us.
            debug 'Converting ipaddresses to hostnames '\
                  "for replicaset #{name.inspect}"
            intended_config.replace_member_hosts_with_fqdns_from replicaset_config
          else
            # Modify the desired replicaset config to:
            debug "Updating members for replicaset #{name.inspect}"
            # - delete records for currently active members which are
            #   not specified by our desired configuration
            intended_config.remove_members_absent_from replicaset_config
            # - update existing member records to match their existing
            #   _id attributes
            intended_config.update_member_attributes_while_keeping_ids_from replicaset_config
            # - add the new member records which are not yet active
            #   (and so don't have existing _id attributes)
            intended_config.add_members_adjuct_to replicaset_config
          end

          result = nil
          begin
            # Because this update may cause existing members to drop
            # out of the replicaset, we need to collect all of them.
            existing_members = current_config['members'].map do |m|
              m['host']
            end
            # And connect to all the existing members.
            connection = replset_connection_to! existing_members
            # And submit our updated configuration
            info "Reconfiguring replicaset: #{name.inspect} "\
                 "with updated config: #{intended_config.inspect}"
            result = connection.replicaset_reconfigure intended_config, :check_response => false
          rescue Mongo::ConnectionFailure
            # Reconfiguring destroys exisiting connections. This is
            # expected and safely recoverable.
          end
          # Finally we request our current config
          current_config = current_replicaset_config!
          # and verify it matches.
          if replicaset_config.matches? current_config
            # If it matches, we're successful and satisfied
            debug 'New config successfully applied: '\
                  "#{current_config.inspect}"
            return
          else
            # Otherwise we've done our best and still failed.
            fail 'Failed to apply new config. '\
                 "Current config: #{current_config.inspect} "\
                 "Target config: #{replicaset_config.inspect}"
          end
        end
      end
      # All reasonable code paths should have either returned or failed
      # by now, we should never arrive here.
      fail 'Failed to configure replicaset and in an unknown state.'\
           "Last request result: #{result.inspect}"
    end

    private

    def current_replicaset_config!(opts)
      connection = slave_connection! opts[:from]
      info 'Requesting current config for '\
           "replicaset: #{name.inspect} "\
           "from: #{opts[:from] || 'local service'}"
      raw_config = connection['local']['system']['replset']
        .find_one('_id' => name)
      ReplicasetConfig.from_config raw_config
    end

    ### Connection helpers
    def slave_connection!(host_record = nil)
      host_record ||= local_host_record
      connection = nil
      rescue_connection_failure do
        debug 'Checking connection by requesting database names'
        connection = Mongo::Connection.new(
          host_record['hostname'],
          host_record['port'],
          :op_timeout => 5,
          :slave_ok => true
        )
      end
    end

    def replset_connection_to!(hosts)
      rs_connection = nil
      rescue_connection_failure do
        rs_connection = Mongo::ReplSetConnection.new hosts
        debug 'Checking connection by requesting database names'
        rs_connection.database_names # check connection
      end
      rs_connection
    end

    ### doc predicates
    def ok?(doc)
      Mongo::Support.ok? doc
    end

    # returns server, port if doc contains an already initialized error
    def already_initialized_err?(doc)
      errmsg = doc.fetch('errmsg', nil)
      if errmsg =~ /(\S+) is already initiated/
        # replicaset is initialized, requires reconfig
        # retrieve host from errmsg
        match = Regexp.last_match
        hostname, port = match[1].split(':')
        { 'hostname' => hostname, 'port' => port }
      elsif errmsg == 'already initialized'
        # this means we can use local service
        local_host_record
      else
        false
      end
    end

    # Ensure retry upon failure using constant backoff
    def rescue_connection_failure(max_retries = 30)
      # TODO: investigate truncated binary exponential backoff
      retries = 0
      begin
        yield
      rescue Mongo::ConnectionFailure => ex
        retries += 1
        raise ex if retries > max_retries
        sleep(0.5)
        retry
      end
    end
  end
end

