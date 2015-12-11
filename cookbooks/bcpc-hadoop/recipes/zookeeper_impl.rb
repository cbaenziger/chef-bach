::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

package  hwx_pkg_str('zookeeper-server', node[:bcpc][:hadoop][:distribution][:release]) do
  action :upgrade
end

include_recipe 'bcpc-hadoop::zookeeper_config'

bash "hdp-select zookeeper-server" do
  code "hdp-select set zookeeper-server #{node[:bcpc][:hadoop][:distribution][:release]}"
  subscribes :run, "package[#{hwx_pkg_str('zookeeper-server', node[:bcpc][:hadoop][:distribution][:release])}]", :immediate
  action :nothing
end

user_ulimit "zookeeper" do
  filehandle_limit 32769
end

link '/etc/init.d/zookeeper-server' do
  to "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/zookeeper/etc/init.d/zookeeper-server"
end

directory "/var/run/zookeeper" do 
  owner "zookeeper"
  group "zookeeper"
  mode "0755"
  action :create
end

link "/usr/bin/zookeeper-server-initialize" do
  to "/usr/hdp/current/zookeeper-client/bin/zookeeper-server-initialize"
end

template "#{node[:bcpc][:hadoop][:zookeeper][:conf_dir]}/zookeeper-env.sh" do
  source "zk_zookeeper-env.sh.erb"
  mode 0644
  variables(:zk_jmx_port => node[:bcpc][:hadoop][:zookeeper][:jmx][:port])
end

directory node[:bcpc][:hadoop][:zookeeper][:data_dir] do
  recursive true
  owner node[:bcpc][:hadoop][:zookeeper][:owner]
  group node[:bcpc][:hadoop][:zookeeper][:group]
  mode 0755
end

template "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/zookeeper/bin/zkServer.sh" do
  source "zk_zkServer.sh.erb"
end

bash "init-zookeeper" do
  code "service zookeeper-server init --myid=#{node[:bcpc][:node_number]}"
  not_if { ::File.exists?("#{node[:bcpc][:hadoop][:zookeeper][:data_dir]}/myid") }
end

file "#{node[:bcpc][:hadoop][:zookeeper][:data_dir]}/myid" do
  content node[:bcpc][:node_number]
  owner node[:bcpc][:hadoop][:zookeeper][:owner]
  group node[:bcpc][:hadoop][:zookeeper][:group]
  mode 0644
end

service "zookeeper-server" do
  supports :status => true, :restart => true, :reload => false
  action [:enable, :start]
  subscribes :restart, "template[#{node[:bcpc][:hadoop][:zookeeper][:conf_dir]}/zoo.cfg]", :delayed
  subscribes :restart, "template[#{node[:bcpc][:hadoop][:zookeeper][:conf_dir]}/zookeeper-env.sh]", :delayed
  subscribes :restart, "link[/usr/lib/zookeeper/bin/zkServer.sh]", :delayed
  subscribes :restart, "file[#{node[:bcpc][:hadoop][:zookeeper][:data_dir]}/myid]", :delayed
  subscribes :restart, "user_ulimit[zookeeper]", :delayed
  subscribes :restart, "bash[hdp-select zookeeper-server]", :delayed
end
