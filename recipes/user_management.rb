chef_gem 'mongo'

users = []
admin = node['mongodb']['admin']

# If authentication is required,
# add the admin to the users array for adding/updating
users << admin if node['mongodb']['config']['auth'] == true

users.concat(node['mongodb']['users'])

service 'mongodb' do
  action :restart
end

# Retry 5 times to make sure mongodb is started
execute 'wait for mongodb' do
  command 'mongo'
  action :run
  retries 5
  retry_delay 10
end

# Add each user specified in attributes
users.each do |user|
  mongodb_user user['username'] do
    password user['password']
    roles user['roles']
    database user['database']
    connection node['mongodb']
    action :add
  end
end
