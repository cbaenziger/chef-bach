include_recipe 'bcpc-hadoop::hadoop_config'
::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
::Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

node[:bcpc][:hadoop][:mounts].each do |i|
  directory "/disk/#{i}/yarn/local" do
    owner "yarn"
    group "yarn"
    mode 0755
    action :create
    recursive true
  end

  directory "/disk/#{i}/yarn/logs" do
    owner "yarn"
    group "yarn"
    mode 0755
    action :create
    recursive true
  end
end

["", "done", "done_intermediate"].each do |dir|
  bash "create-hdfs-history-dir #{dir}" do
    code "hdfs dfs -mkdir /user/history/#{dir} && hdfs dfs -chmod 1777 /user/history/#{dir} && hdfs dfs -chown yarn:mapred /user/history/#{dir}"
    user "hdfs"
    not_if "hdfs dfs -test -d /user/history/#{dir}", :user => "hdfs"
  end
end

bash "create-hdfs-yarn-log" do
  code "hdfs dfs -mkdir -p /var/log/hadoop-yarn && hdfs dfs -chmod 1777 /var/log/hadoop-yarn && hdfs dfs -chown yarn:mapred /var/log/hadoosp-yarn"
  user "hdfs"
  not_if "hdfs dfs -test -d /var/log/hadoop-yarn", :user => "hdfs"
end

# list hdp packages to install
%w{hadoop-yarn-resourcemanager hadoop-client hadoop-mapreduce}.each do |pkg|
  package hwx_pkg_str(pkg, node[:bcpc][:hadoop][:distribution][:release]) do
    action :install
  end

  bash "hdp-select #{pkg}" do
    code "hdp-select set #{pkg} #{node[:bcpc][:hadoop][:distribution][:release]}"
    subscribes :run, "package[#{pkg}]", :immediate
    action :nothing
  end
end

# list of hdp-select values from packages above
%w{hadoop-yarn-resourcemanager hadoop-client hadoop-mapreduce-server}.each do |pkg|
  bash "hdp-select #{pkg}" do
    code "hdp-select set #{pkg} #{node[:bcpc][:hadoop][:distribution][:release]}"
    subscribes :run, "package[#{hwx_pkg_str(pkg, node[:bcpc][:hadoop][:distribution][:release])}]", :immediate
    action :nothing
  end
end

link "/etc/init.d/hadoop-yarn-resourcemanager" do
  to "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop-yarn/etc/init.d/hadoop-yarn-resourcemanager"
end

bash "setup-mapreduce-app" do
  code <<-EOH
  hdfs dfs -mkdir -p /hdp/apps/#{node[:bcpc][:hadoop][:distribution][:release]}/mapreduce/
  hdfs dfs -put /usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop/mapreduce.tar.gz /hdp/apps/#{node[:bcpc][:hadoop][:distribution][:release]}/mapreduce/
  hdfs dfs -chown -R hdfs:hadoop /hdp
  hdfs dfs -chmod -R 555 /hdp/apps/#{node[:bcpc][:hadoop][:distribution][:release]}/mapreduce
  hdfs dfs -chmod -R 444 /hdp/apps/#{node[:bcpc][:hadoop][:distribution][:release]}/mapreduce/mapreduce.tar.gz
  EOH
  user "hdfs"
  not_if "hdfs dfs -test -f /hdp/apps/#{node[:bcpc][:hadoop][:distribution][:release]}/mapreduce/mapreduce.tar.gz", :user => "hdfs" 
  only_if "echo 'test' | hdfs dfs -copyFromLocal - /tmp/mapred-test", :user => "hdfs"
end

bash "delete-temp-file" do
  code <<-EOH
  hdfs dfs -rm /tmp/mapred-test
  EOH
  user "hdfs"
  action :nothing
end

service "hadoop-yarn-resourcemanager" do
  action [:enable, :start]
  supports :status => true, :restart => true, :reload => false
  subscribes :restart, "template[/etc/hadoop/conf/hadoop-env.sh]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/yarn-env.sh]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/yarn-site.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/mapred-site.xml]", :delayed
  subscribes :restart, "bash[hdp-select hadoop-yarn-resourcemanager]", :delayed
end

bash "reload mapreduce nodes" do
  code "yarn rmadmin -refreshNodes"
  user "mapred"
  action :nothing
  subscribes :run, "template[/etc/hadoop/conf/yarn.exclude]", :delayed
end
