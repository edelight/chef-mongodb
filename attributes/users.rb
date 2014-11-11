# The username / password combination that is used
# to authenticate with the mongo database
default['mongodb']['authentication']['username'] = 'admin'
default['mongodb']['authentication']['password'] = 'admin'

default['mongodb']['admin'] = {
  'username' => default['mongodb']['authentication']['username'],
  'password' => default['mongodb']['authentication']['password'],
  'roles' => %w(userAdminAnyDatabase dbAdminAnyDatabase clusterAdmin),
  'database' => 'admin'
}

default['mongodb']['users'] = []

# Force creation of admin user. auth=true is an invalid
# setting for mongos so this is needed to ensure the admin
# user is created
default['mongodb']['mongos_create_admin'] = false

# For connecting to mongo on localhost, retries to make after
# connection failures and delay in seconds to retry
default['mongodb']['user_management']['connection']['retries'] = 2
default['mongodb']['user_management']['connection']['delay'] = 2

# For mongod replicasets, the delay in seconds and number
# of times to retry adding a user. Used to handle election
# of primary not being completed immediately
default['mongodb']['mongod_create_user']['retries'] = 2
default['mongodb']['mongod_create_user']['delay'] = 10
