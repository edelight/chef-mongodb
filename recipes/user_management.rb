chef_gem 'mongo' do
  version '1.10.2'
end

# Set default to true if this recipe is included
node.default['mongodb']['config']['auth'] = true

users = []
admin = node['mongodb']['admin']

# If authentication is required,
# add the admin to the users array for adding/updating
users << admin if node['mongodb']['config']['auth'] == true

users.concat(node['mongodb']['users'])

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
