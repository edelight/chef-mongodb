def user_exists?(username, connection)
  connection['admin']['system.users'].find(:user => username).count > 0
end

def add_user(username, password, roles = [], database)
  require 'rubygems'
  require 'mongo'

  connection = retrieve_db
  admin = connection.db('admin')
  db = connection.db(database)

  # Check if user is admin / admin, and warn that this should
  # be overridden to unique values
  if username == 'admin' && password == 'admin'
    Chef::Log.warn('Default username / password detected for admin user')
    Chef::Log.warn('These should be overridden to different, unique values')
  end

  # If authentication is required on database
  # must authenticate as a userAdmin after an admin user has been created
  # this will fail on the first attempt, but user will still be created
  # because of the localhost exception
  if (@new_resource.connection['config']['auth'] == true) || (@new_resource.connection['mongos_create_admin'] == true)
    begin
      admin.authenticate(@new_resource.connection['authentication']['username'], @new_resource.connection['authentication']['password'])
    rescue Mongo::AuthenticationError => e
      Chef::Log.warn("Unable to authenticate as admin user. If this is a fresh install, ignore warning: #{e}")
    end
  end

  # Create the user if they don't exist
  # Update the user if they already exist
  begin
    db.add_user(username, password, false, :roles => roles)
    Chef::Log.info("Created or updated user #{username} on #{database}")
  rescue Mongo::ConnectionFailure => e
    if @new_resource.connection['is_replicaset']
      # Node is part of a replicaset and may not be initialized yet, going to retry if set to
      i = 0
      while i < @new_resource.connection['mongod_create_user']['retries']
        begin
          # See if we can get the current replicaset status back from the node
          cmd = BSON::OrderedHash.new
          cmd['replSetGetStatus'] = 1
          result = admin.command(cmd)
          # Check if the current node in the replicaset status has an info message set (at this point, most likely
          # a message about the election)
          has_info_message = result['members'].select { |a| a['self'] && a.key?('infoMessage') }.count > 0
          if result['myState'] == 1
            # This node is a primary node, try to add the user
            db.add_user(username, password, false, :roles => roles)
            Chef::Log.info("Created or updated user #{username} on #{database} of primary replicaset node")
            break
          elsif result['myState'] == 2 && has_info_message == true
            # This node is secondary but may be in the process of an election, retry
            Chef::Log.info("Unable to add user to secondary, election may be in progress, retrying in #{@new_resource.connection['mongod_create_user']['delay']} seconds...")
          elsif result['myState'] == 2 && has_info_message == false
            # This node is secondary and not in the process of an election, bail out
            Chef::Log.info('Current node appears to be a secondary node in replicaset, could not detect election in progress, not adding user')
            break
          end
        rescue Mongo::ConnectionFailure => e
          # Unable to connect to the node, may not be initialized yet
          Chef::Log.warn("Unable to add user, retrying in #{@new_resource.connection['mongod_create_user']['delay']} second(s)... #{e}")
        rescue Mongo::OperationFailure => e
          # Unable to make either add call or replicaset call on node, should retry in case it was in the middle of being initialized
          Chef::Log.warn("Unable to add user, retrying in #{@new_resource.connection['mongod_create_user']['delay']} second(s)... #{e}")
        end
        i += 1
        sleep(@new_resource.connection['mongod_create_user']['delay'])
      end
    else
      Chef::Log.fatal("Unable to add user: #{e}")
    end
  end
end

# Drop a user from the database specified
def delete_user(username, database)
  require 'rubygems'
  require 'mongo'

  connection = retrieve_db
  admin = connection.db('admin')
  db = connection.db(database)

  # Only try to authenticate with db if required
  if (@new_resource.connection['config']['auth'] == true) || (@new_resource.connection['mongos_create_admin'] == true)
    begin
      admin.authenticate(@new_resource.connection['authentication']['username'], @new_resource.connection['authentication']['password'])
    rescue Mongo::AuthenticationError => e
      Chef::Log.warn("Unable to authenticate as admin user: #{e}")
    end
  end

  if user_exists?(username, connection)
    db.remove_user(username)
    Chef::Log.info("Deleted user #{username} on #{database}")
  else
    Chef::Log.warn("Unable to delete non-existent user #{username} on #{database}")
  end
end

# Get the MongoClient connection
def retrieve_db(attempt = 0)
  require 'rubygems'
  require 'mongo'

  begin
    Mongo::MongoClient.new(
      @new_resource.connection['host'],
      @new_resource.connection['port'],
      :connect_timeout => 15,
      :slave_ok => true
    )
  rescue Mongo::ConnectionFailure => e
    if(attempt) < @new_resource.connection['user_management']['connection']['retries']
      Chef::Log.warn("Unable to connect to MongoDB instance, retrying in #{@new_resource.connection['user_management']['connection']['delay']} second(s)...")
      sleep(@new_resource.connection['user_management']['connection']['delay'])
      retrieve_db(attempt + 1)
    end
  end
end

action :add do
  add_user(new_resource.username, new_resource.password, new_resource.roles, new_resource.database)
end

action :delete do
  delete_user(new_resource.username, new_resource.database)
end

action :modify do
  add_user(new_resource.username, new_resource.password, new_resource.roles, new_resource.database)
end
