include_recipe 'dpkg_autostart'
include_recipe 'bcpc-hadoop::hadoop_config'
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
    code "hadoop fs -mkdir /user/history/#{dir} && hadoop fs -chmod 1777 /user/history/#{dir} && hadoop fs -chown yarn:mapred /user/history/#{dir}"
    user "hdfs"
   not_if "sudo -u hdfs hadoop fs -test -d /user/history/#{dir}"
  end
end

bash "create-hdfs-yarn-log" do
  code "hadoop fs -mkdir -p /var/log/hadoop-yarn && hadoop fs -chmod 1777 /var/log/hadoop-yarn && hadoop fs -chown yarn:mapred /var/log/hadoosp-yarn"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /var/log/hadoop-yarn"
end

%w{hadoop-yarn-resourcemanager hadoop-client hadoop-mapreduce}.each do |pkg|
  dpkg_autostart pkg do
    allow false
  end

  package pkg do
    action :upgrade
  end

  bash "hdp-select #{pkg}" do
    code "hdp-select set #{pkg} #{node[:bcpc][:hadoop][:distribution][:release]}"
    subscribes :run, "package[#{pkg}]", :immediate
    action :nothing
  end
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
  not_if "sudo -u hdfs hdfs dfs -test -f /hdp/apps/#{node[:bcpc][:hadoop][:distribution][:release]}/mapreduce/mapreduce.tar.gz" 
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
