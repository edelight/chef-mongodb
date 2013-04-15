define :generate_raid_backups do
  aws_creds = data_bag_item(node[:aws][:databag_name], node[:aws][:databag_entry])
#  volumes = node[:backups][:mongo_volumes].join(" ")
  region = node[:ec2][:placement_availability_zone][0...-1] unless !node[:ec2] or !node[:ec2][:placement_availability_zone]

  if !region
    region = 'us-west-2'
    Chef::Log.warn("Could not find ec2.placement_availability_zone attribute for node; defaulting region to #{region} for EBS RAID snapshotting.")
  end

  template "/usr/local/bin/raid_snapshot.sh" do
    source "raid_snapshot.sh.erb"
    owner "root"
    group "root"
    mode "0755"
    variables("seckey" => aws_creds["aws_secret_access_key"],
              "awskey" => aws_creds["aws_access_key_id"],
              "region" => region)
  end
end

