include_recipe 'bcpc-hadoop::hadoop_config'
::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

node.default['bcpc']['hadoop']['copylog']['datanode'] = {
    'logfile' => "/var/log/hadoop-hdfs/hadoop-hdfs-datanode-#{node.hostname}.log",
    'docopy' => true
}

%w{hadoop-hdfs-datanode}.each do |pkg|
  package pkg do
    action :upgrade
  end

  bash "hdp-select #{pkg}" do
    code "hdp-select set #{pkg} #{node[:bcpc][:hadoop][:distribution][:release]}"
    subscribes :run, "package[#{hwx_pkg_str(pkg, node[:bcpc][:hadoop][:distribution][:release], node[:platform_family])}]", :immediate
    action :nothing
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

# need to ensure hdfs user is in hadoop and hdfs
# groups. Packages will not add hdfs if it
# is already created at install time (e.g. if
# machine is using LDAP for users).

# Create all the resources to add them in resource collection
node[:bcpc][:hadoop][:os][:group].keys.each do |group_name|
  node[:bcpc][:hadoop][:os][:group][group_name][:members].each do|user_name|
    user user_name do
      home "/var/lib/hadoop-#{user_name}"
      shell '/bin/bash'
      system true
      action :create
      not_if { user_exists?(user_name) }
    end
  end

  group group_name do
    append true
    members node[:bcpc][:hadoop][:os][:group][group_name][:members]
    action :nothing
  end
end
  
# Take action on each group resource based on its existence 
ruby_block 'create_or_manage_groups' do
  block do
    node[:bcpc][:hadoop][:os][:group].keys.each do |group_name|
      res = run_context.resource_collection.find("group[#{group_name}]")
      res.run_action(get_group_action(group_name))
    end
  end
end

directory "/var/run/hadoop-hdfs" do
  owner "hdfs"
  group "root"
end

link "/etc/init.d/hadoop-hdfs-datanode" do
  to "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop-hdfs/etc/#{node["platform_family"] == 'rhel' ? "rc.d/" : ""}init.d/hadoop-hdfs-datanode"
end

# Setup datanode and nodemanager bits
if node[:bcpc][:hadoop][:mounts].length <= node[:bcpc][:hadoop][:hdfs][:failed_volumes_tolerated]
  Chef::Application.fatal!("You have fewer #{node[:bcpc][:hadoop][:mounts].length} disks than #{node[:bcpc][:hadoop][:hdfs][:failed_volumes_tolerated]} volumes tolerated! See comments of HDFS-4442.")
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
           "bash[hdp-select hadoop-hdfs-datanode]",
           "ruby_block[handle_prev_datanode_restart_failure]"]

hadoop_service "hadoop-hdfs-datanode" do
  dependencies dn_deps
  process_identifier "org.apache.hadoop.hdfs.server.datanode.DataNode"
end
