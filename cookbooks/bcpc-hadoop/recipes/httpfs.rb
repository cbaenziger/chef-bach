include_recipe 'bcpc-hadoop::hadoop_config'
include_recipe 'bcpc-hadoop::httpfs_config'
::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

package hwx_pkg_str("hadoop-httpfs", node[:bcpc][:hadoop][:distribution][:release]) do
  action :upgrade
end

bash "hdp-select hadoop-httpfs" do
  code "hdp-select set hadoop-httpfs #{node[:bcpc][:hadoop][:distribution][:release]}"
  subscribes :run, "package[#{hwx_pkg_str("hadoop-httpfs", node[:bcpc][:hadoop][:distribution][:release])}]", :immediate
  action :nothing
end

link "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop-httpfs/conf" do
  to "/usr/hdp/<#{node[:bcpc][:hadoop][:distribution][:release]}/etc/hadoop-httpfs/tomcat-deployment.dist/conf"
end

link '/etc/init.d/hadoop-httpfs' do
  to "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop-httpfs/etc/init.d/hadoop-httpfs"
end

service "hadoop-httpfs" do
  action [:enable, :start]
  supports :status => true, :restart => true, :reload => false
  subscribes :restart, "template[/etc/hadoop-httpfs/conf/httpfs-site.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hadoop-env.sh]", :delayed
  subscribes :restart, "bash[hdp-select hadoop-httpfs]", :immediate
end
