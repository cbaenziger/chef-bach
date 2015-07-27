include_recipe 'bcpc-hadoop::hadoop_config'
include_recipe 'bcpc-hadoop::hive_config'

node.default['bcpc']['hadoop']['copylog']['datanode'] = {
    'logfile' => "/var/log/hadoop-hdfs/hadoop-hdfs-datanode-#{node.hostname}.log",
    'docopy' => true
}

%w{hadoop-hdfs-datanode}.each do |pkg|
  package pkg do
    action :upgrade
  end
end

user_ulimit "root" do
  filehandle_limit 32769
  process_limit 65536
end

user_ulimit "hdfs" do
  filehandle_limit 32769
  process_limit 65536
end

if node[:bcpc][:hadoop][:mounts].length <= node[:bcpc][:hadoop][:hdfs][:failed_volumes_tolerated]
  Chef::Application.fatal!("You have fewer #{node[:bcpc][:hadoop][:disks]} than #{node[:bcpc][:hadoop][:hdfs][:failed_volumes_tolerated]}! See comments of HDFS-4442.")
end

# Build nodes for HDFS storage
node[:bcpc][:hadoop][:mounts].each do |i|
  directory "/disk/#{i}/dfs" do
    owner "hdfs"
    group "hdfs"
    mode 0700
    action :create
  end
  directory "/disk/#{i}/dfs/dn" do
    owner "hdfs"
    group "hdfs"
    mode 0700
    action :create
  end
end

dn_deps = ["template[/etc/hadoop/conf/hdfs-site.xml]",
           "template[/etc/hadoop/conf/hadoop-env.sh]",
           "template[/etc/hadoop/conf/topology]",
           "user_ulimit[hdfs]",
           "user_ulimit[root]",
           "ruby_block[handle_prev_datanode_restart_failure]"]

hadoop_service "hadoop-hdfs-datanode" do
  dependencies dn_deps
  process_identifier "org.apache.hadoop.hdfs.server.datanode.DataNode"
end
