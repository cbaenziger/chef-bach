include_recipe 'bcpc-hadoop::hadoop_config'

%w{hadoop-mapreduce-historyserver hadoop-yarn-proxyserver}.each do |pkg|
  package pkg do
      action :upgrade
  end
end

service "hadoop-yarn-proxyserver" do 
  action [:enable, :restart]
  supports :status => true, :restart => true, :reload => false
end

bash "hdp-select hadoop-yarn-historyserver" do
  code "hdp-select set hadoop-yarn-historyserver #{node[:bcpc][:hadoop][:distribution][:release]}"
  subscribes :run, "package[hadoop-yarn-historyserver]", :immediate
  action :nothing
end

service "hadoop-yarn-historyserver" do 
  action [:enable, :restart]
  supports :status => true, :restart => true, :reload => false
  subscribes :restart, "bash[hdp-select hadoop-yarn-historyserver]", :immediate
end
