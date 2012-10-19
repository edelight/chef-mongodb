include_recipe 'lvm::default'

drives = Dir.glob('/dev/xvd*').sort.select { |x| /\/dev\/xvd[fghijklmnop].*/.match(x) }


# Don't create the mdadm.conf file until after the array has been created
template '/etc/mdadm.conf' do
    action :nothing
    source 'mdadm.conf.erb'
    variables( {
        :devices => drives,
        :regex => /ARRAY (.*) metadata=(.*) .*UUID=(.*)/,
        :level => 10,
    })
end

mdadm "/dev/md0" do
    devices drives
    level node["mongodb"]["raid"]["level"]
    action [ :create, :assemble ]
    notifies :create, "template[/etc/mdadm.conf]"
end

# Get the array details to build the mdadm.conf

lvm_volume_group 'mongodb' do
    physical_volumes [ "/dev/md0" ]
end

lvm_logical_volume 'data' do
    group "mongodb"
    size node['mongodb']['raid']['data_size']
    filesystem 'ext4'
    mount_point :location => '/var/lib/mongodb', :options => 'defaults,auto,noatime,noexec'
end
lvm_logical_volume 'journal' do
    group "mongodb"
    size node['mongodb']['raid']['journal_size']
    filesystem 'ext4'
    mount_point :location => '/var/lib/mongodb/journal', :options => 'defaults,auto,noatime,noexec'
end
lvm_logical_volume 'log' do
    group "mongodb"
    size node['mongodb']['raid']['log_size']
    filesystem 'ext4'
    mount_point :location => '/var/log/mongodb', :options => 'defaults,auto,noatime,noexec'
end



