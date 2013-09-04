
include_recipe 'tealium_bongo'

cookbook_file '/usr/local/bin/bongo' do
   source 'bongo'
   owner 'root'
   mode '0755'
   action :create
end

# FYI: The backup script defaults to the 'development' cluster
# if --cluster is not used.

if node['mongodb']['cluster_name'].nil?
   cluster_opt = ""
else
   cluster_opt = "--cluster #{node['mongodb']['cluster_name']}"
end

if node['mongodb']['raid'].nil?
   if node['mongodb']['data_root'].nil?
      data_path = node['mongodb']['dbpath']
   else
      data_path = node['mongodb']['data_root']
   end
else
   data_path = node['mongodb']['raid_mount']
end


# FYI: The backup script logs to syslog by default.

cron "mongodb-backup" do
   minute node['mongodb']['backup']['minute']
   hour  node['mongodb']['backup']['hour']
   user  "root"
   shell "/bin/bash"
   command "/usr/local/bin/bongo --data #{data_path} #{cluster_opt} 2>&1 | /usr/bin/logger -t bongo"
end

