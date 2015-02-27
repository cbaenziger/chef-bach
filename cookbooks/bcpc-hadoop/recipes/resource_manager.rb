include_recipe 'dpkg_autostart'
include_recipe 'bcpc-hadoop::hadoop_config'

ruby_block "Create YARN Local Directories" do
  block do
    node[:bcpc][:storage][:mounts].each_index do |i|
      ["local", "logs"].each do |d|
        dir = Chef::Resource::Directory.new("#{node["bcpc"]["storage"]["disks"]["mount_root"]}/#{i}/yarn/#{d}", run_context)
        dir.owner "yarn"
        dir.group "yarn"
        dir.mode 00755
        dir.recursive true
        dir.run_action :create
      end
    end
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
end

service "hadoop-yarn-resourcemanager" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/hadoop/conf/hadoop-env.sh]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/yarn-site.xml]", :delayed
end

bash "reload mapreduce nodes" do
  code "yarn rmadmin -refreshNodes"
  user "mapred"
  action :nothing
  subscribes :run, "template[/etc/hadoop/conf/mapred.exclude]", :delayed
end
