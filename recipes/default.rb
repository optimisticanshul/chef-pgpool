#
# Cookbook Name:: pgpool
# Recipe:: default
#
# Copyright 2015, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
instance = instance = search("aws_opsworks_instance", "self:true").first
other_pgpool_hostname = ''
route_file = '/home/ubuntu/route.json'
search("aws_opsworks_instance").each do |i|
  if i['private_ip'] != instance['private_ip']
    other_pgpool_hostname = i['private_ip']
    Chef::Log.info("********** other_pgpool_hostname '#{i['private_ip']}' **********")
  end
end

if_up_cmd = "aws route53 change-resource-record-sets --hosted-zone-id #{node['route53']['hosted_zone_id']} --change-batch file://#{route_file}"
node.override['pgpool']['pgconf']['other_pgpool_hostname0'] = other_pgpool_hostname
node.override['pgpool']['pgconf']['if_up_cmd'] = if_up_cmd

template "#{route_file}" do
  owner 'ubuntu'
  group 'ubuntu'
  action :create
  variables({
    other_pgpool_hostname: other_pgpool_hostname
  })
end

file "#{node['pgpool']['config']['dir']}/pool_passwd" do
  owner node['pgpool']['user']
  group node['pgpool']['group']
  action :create
end

package node['pgpool']['config']['package_name'] do
  action :install
end

case node['platform']
when 'debian', 'ubuntu'
package 'postgresql-client' do
  action :install
end
end
group node['pgpool']['group'] do
  action :create
end

user node['pgpool']['user'] do
  action :create
  gid node['pgpool']['group']
end

%w(pgpool pcp pool_hba).each do |f|
  template "#{node['pgpool']['config']['dir']}/#{f}.conf" do
    owner 'root'
    group 'root'
    mode 0644
    notifies :restart, 'service[pgpool]', :delayed
  end
end

file "#{node['pgpool']['config']['dir']}/pool_passwd" do
  owner node['pgpool']['user']
  group node['pgpool']['group']
  action :create
end

%w(
  logdir
  socket_dir
  pcp_socket_dir
).each do |dir|
  directory node['pgpool']['pgconf'][dir] do
    action :create
    owner node['pgpool']['user']
    group node['pgpool']['group']
    mode 0755
  end
end

service 'pgpool' do
  service_name node['pgpool']['service']
  action [:enable, :start]
end
