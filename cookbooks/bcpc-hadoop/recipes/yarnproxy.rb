include_recipe 'bcpc-hadoop::hadoop_config'
::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

%w{hadoop-mapreduce-historyserver hadoop-yarn-proxyserver}.each do |pkg|
  package hwx_pkg_str(pkg, node[:bcpc][:hadoop][:distribution][:release], node[:platform_family]) do
      action :upgrade
  end
end

service "hadoop-yarn-proxyserver" do 
  action [:enable, :restart]
  supports :status => true, :restart => true, :reload => false
end

bash "hdp-select hadoop-yarn-historyserver" do
  code "hdp-select set hadoop-yarn-historyserver #{node[:bcpc][:hadoop][:distribution][:release]}"
  subscribes :run, "package[#{hwx_pkg_str("hadoop-yarn-historyserver", node[:bcpc][:hadoop][:distribution][:release], node[:platform_family])}]", :immediate
  action :nothing
end

service "hadoop-yarn-historyserver" do 
  action [:enable, :restart]
  supports :status => true, :restart => true, :reload => false
  subscribes :restart, "bash[hdp-select hadoop-yarn-historyserver]", :immediate
end
