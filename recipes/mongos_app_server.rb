#
# Cookbook Name:: mongodb
# Recipe:: mongos_app_server
#
# Purely a hack to allow us to include mongodb::default without launching
# a standalone mongod.  And then the including cookbook can set up as many
# instances of mongos as it needs.
#

include_recipe "mongodb"

