include_recipe 'bcpc-hadoop::hadoop_config'
::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

%w{hadoop-mapreduce-historyserver}.each do |pkg|
  package hwx_pkg_str(pkg, node[:bcpc][:hadoop][:distribution][:release]) do
    action :upgrade
  end

  bash "hdp-select set #{pkg} #{node[:bcpc][:hadoop][:distribution][:release]}" do
    subscribes :run, "package[#{hwx_pkg_str(pkg, node[:bcpc][:hadoop][:distribution][:release])}]", :immediate
    action :nothing
  end
end

link "/etc/init.d/hadoop-mapreduce-historyserver" do
  to "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop-mapreduce/etc/init.d/hadoop-mapreduce-historyserver"
end

template "/etc/hadoop/conf/mapred-env.sh" do
  source "hdp_mapred-env.sh.erb"
  mode 0655
end

bash "create-hdfs-history-dir" do
  code <<-EOH
  hdfs dfs -mkdir -p /var/log/hadoop-yarn/apps
  hdfs dfs -chmod -R 1777 /var/log/hadoop-yarn/apps
#  hdfs dfs -mkdir -p /mr-history/done
#  hdfs dfs -chmod -R 1777 /mr-history/done
#  hdfs dfs -chown -R mapred:hdfs /mr-history
#  hdfs dfs -mkdir -p /app-logs
#  hdfs dfs -chmod -R 1777 /app-logs
#  hdfs dfs -chown yarn /app-logs
  EOH
  user "hdfs"
#  not_if "sudo -u hdfs hadoop dfs -test -d /mr-history"
  not_if "hdfs dfs -test -d /var/log/hadoop-yarn/apps", :user => "hdfs"
end

service "hadoop-mapreduce-historyserver" do
  supports :status => true, :restart => true, :reload => false
  action [:enable, :start]
  subscribes :restart, "template[/etc/hadoop/conf/hadoop-env.sh]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/mapred-site.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/yarn-site.xml]", :delayed
end
