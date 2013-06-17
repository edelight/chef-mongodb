#
# Cookbook Name:: mongo_test
# Recipe:: default
#
include_recipe "mongodb"

mongodb_user "someguy" do
  password "s3cu43"
  database "gbs_for_dbs"
  retries 3
  retry_delay 10
end
