require "base64"
require "digest"
require 'mixlib/shellout'

include_recipe 'dpkg_autostart'
include_recipe 'bcpc-hadoop::hadoop_config'
include_recipe 'bcpc-hadoop::namenode_queries'

#
# Updating node attribuetes to copy namenode log files to centralized location (HDFS)
#
node.default['bcpc']['hadoop']['copylog']['namenode_master'] = {
    'logfile' => "/var/log/hadoop-hdfs/hadoop-hdfs-namenode-#{node.hostname}.log",
    'docopy' => true
}

node.default['bcpc']['hadoop']['copylog']['namenode_master_out'] = {
    'logfile' => "/var/log/hadoop-hdfs/hadoop-hdfs-namenode-#{node.hostname}.out",
    'docopy' => true
}

%w{hadoop-hdfs-namenode hadoop-hdfs-zkfc hadoop-mapreduce}.each do |pkg|
  dpkg_autostart pkg do
    allow false
  end
  package pkg do
    action :upgrade
  end
end

ruby_block "hadoop disks" do
  block do
    node[:bcpc][:hadoop][:mounts].each do |d|
      dir = Chef::Resource::Directory.new("/disk/#{d}/dfs/nn", run_context)
      dir.owner "hdfs"
      dir.group "hdfs"
      dir.mode 0755
      dir.recursive "true"
      dir.run_action :create

      exe = Chef::Resource::Execute.new("fixup nn owner", run_context)
      exe.command "chown -Rf hdfs:hdfs /disk/#{d}/dfs"
      exe.only_if { Etc.getpwuid(File.stat("/disk/#{d}/dfs/").uid).name != "hdfs" }
    end
  end
end

template "/etc/init.d/hadoop-hdfs-namenode" do
  source "hdp_hadoop-hdfs-namenode-initd.erb"
  mode 0655
end

template "/etc/init.d/hadoop-hdfs-zkfc" do
  source "hdp_hadoop-hdfs-zkfc-initd.erb"
  mode 0655
end

bash "format namenode" do
  code "hdfs namenode -format -nonInteractive -force"
  user "hdfs"
  action :run
  creates lazy { "/disk/#{node[:bcpc][:hadoop][:mounts][1]}/dfs/nn/current/VERSION" }
  not_if { lazy { node[:bcpc][:hadoop][:mounts].any? { |d| File.exists?("/disk/#{d}/dfs/nn/current/VERSION") } }.call }
end

bash "format-zk-hdfs-ha" do
  code "yes | hdfs zkfc -formatZK"
  action :run
  user "hdfs"
  notifies :restart, "service[generally run hadoop-hdfs-namenode]", :delayed
  zks = node[:bcpc][:hadoop][:zookeeper][:servers].map{|zkh| "#{zkh[:hostname]}:#{node[:bcpc][:hadoop][:zookeeper][:port]}"}.join(",")
  not_if { znode_exists?("/hadoop-ha/#{node.chef_environment}", zks) }
end

service "hadoop-hdfs-zkfc" do
  supports :status => true, :restart => true, :reload => false
  action [:enable, :start]
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site_HA.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-policy.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hadoop-env.sh]", :delayed
end

# need to bring the namenode down to initialize shared edits
service "bring hadoop-hdfs-namenode down for shared edits and HA transition" do
  service_name "hadoop-hdfs-namenode"
  action :stop
  supports :status => true
  notifies :run, "bash[initialize-shared-edits]", :immediately
  only_if { lazy { node[:bcpc][:hadoop][:mounts].all? { |d| not File.exists?("/disk/#{d}/dfs/jn/#{node.chef_environment}/current/VERSION") } }.call }
end

bash "initialize-shared-edits" do
  code "hdfs namenode -initializeSharedEdits"
  user "hdfs"
  action :nothing
end

service "generally run hadoop-hdfs-namenode" do
  action [:enable, :start]
  supports :status => true, :restart => true, :reload => false
  service_name "hadoop-hdfs-namenode"
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-policy.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site_HA.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hadoop-env.sh]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/topology]", :delayed
  subscribes :restart, "user_ulimit[hdfs]", :delayed
  subscribes :restart, "bash[initialize-shared-edits]", :immediately
end

## We need to bootstrap the standby and journal node transaction logs
# The -bootstrapStandby and -initializeSharedEdits don't actually work
# when the namenode starts up, because it is in safemode and won't commit
# a txn.
# So we fake the formatting of the txn directories by copying over current/VERSION
# this tricks the journalnodes and namenodes into thinking they've been formatted.

ruby_block "create-format-UUID-File" do
  block do
    Dir.chdir("/disk/#{node[:bcpc][:hadoop][:mounts][0]}/dfs/") do
      system("tar czvf #{Chef::Config[:file_cache_path]}/nn_fmt.tgz nn/current/VERSION jn/#{node.chef_environment}/current/VERSION")
    end
  end
  action :nothing
  subscribes :run, "service[generally run hadoop-hdfs-namenode]", :immediately
  only_if { File.exists?("#{mount_root}/#{lazy{node[:bcpc][:storage][:mounts][0]}.call}/dfs/nn/current/VERSION") }
end

bash "reload hdfs nodes" do
  code "hdfs dfsadmin -refreshNodes"
  user "hdfs"
  action :nothing
  subscribes :run, "template[/etc/hadoop/conf/dfs.exclude]", :delayed
end

###
# We only want to execute this once, as it is setup of dirs within HDFS.
# We'd prefer to do it after all nodes are members of the HDFS system
#
bash "create-hdfs-temp" do
  code "hadoop fs -mkdir /tmp; hadoop fs -chmod -R 1777 /tmp"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /tmp"
end

bash "create-hdfs-applogs" do
  code "hadoop fs -mkdir /app-logs; hadoop fs -chmod -R 1777 /app-logs; hadoop fs -chown yarn /app-logs"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /app-logs"
end

bash "create-hdfs-user" do
  code "hadoop fs -mkdir /user; hadoop fs -chmod -R 0755 /user"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /user"
end

bash "create-hdfs-history" do
  code "hadoop fs -mkdir /user/history; hadoop fs -chmod -R 1777 /user/history; hadoop fs -chown mapred:hdfs /user/history"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /user/history"
end

bash "create-hdfs-yarn-log" do
  code "hadoop fs -mkdir -p /var/log/hadoop-yarn; hadoop fs -chown yarn:mapred /var/log/hadoop-yarn"
  user "hdfs"
  not_if "sudo -u hdfs hadoop fs -test -d /var/log/hadoop-yarn"
end
