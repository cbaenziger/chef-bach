include_recipe 'bcpc-hadoop::hadoop_config'
include_recipe 'bcpc-hadoop::hive_config'
::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

node.default['bcpc']['hadoop']['copylog']['nodemanager'] = {
    'logfile' => "/var/log/hadoop-yarn/yarn-yarn-nodemanager-#{node.hostname}.log",
    'docopy' => true
}

hdp_select_pkgs = %w{hadoop-yarn-nodemanager
                     hadoop-client}

(hdp_select_pkgs.map{|p| hwx_pkg_str(p, node[:bcpc][:hadoop][:distribution][:release], node[:platform_family])} +
                  %w{hadoop-mapreduce
                     sqoop
                     lzop
                     cgroup-bin
                     hadoop-lzo}).each do |pkg|
  package pkg do
    action :install
  end
end

(hdp_select_pkgs + ['sqoop-client', 'sqoop-server']).each do |pkg|
  bash "hdp-select #{pkg}" do
    code "hdp-select set #{pkg} #{node[:bcpc][:hadoop][:distribution][:release]}"
    subscribes :run, "package[#{hwx_pkg_str(pkg, node[:bcpc][:hadoop][:distribution][:release], node[:platform_family])}]", :immediate
    action :nothing
  end
end

hdp_select_pkgs.each do |pkg|
  bash "hdp-select #{pkg}" do
    code "hdp-select set #{pkg} #{node[:bcpc][:hadoop][:distribution][:release]}"
    subscribes :run, "package[pkg]", :immediate
    action :nothing
  end
end

user_ulimit "mapred" do
  filehandle_limit 32769
  process_limit 65536
end

user_ulimit "yarn" do
  filehandle_limit 32769
  process_limit 65536
end

# need to ensure hdfs user is in hadoop and hdfs
# groups. Packages will not add hdfs if it
# is already created at install time (e.g. if
# machine is using LDAP for users).
# Similarly, yarn needs to be in the hadoop
# group to run the LCE and in the mapred group
# for log aggregation

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

directory "/sys/fs/cgroup/cpu/hadoop-yarn" do
  owner "yarn"
  group "yarn"
  mode 0755
  action :create
end

execute "chown hadoop-yarn cgroup tree to yarn" do
  command "chown -Rf yarn:yarn /sys/fs/cgroup/cpu/hadoop-yarn"
  action :run
end

link "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop/lib/hadoop-lzo-0.6.0.jar" do
  to "/usr/lib/hadoop/lib/hadoop-lzo-0.6.0.jar"
end

link "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop/lib/hadoop-lzo-0.6.0.jar" do
   to "/usr/lib/hadoop/lib/hadoop-lzo-0.6.0.jar"
end
 
link "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop/lib/native/libgplcompression.la" do
   to "/usr/lib/hadoop/lib/native/Linux-amd64-64/libgplcompression.la"
 end
 
link "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop/lib/native/libgplcompression.a" do
   to "/usr/lib/hadoop/lib/native/Linux-amd64-64/libgplcompression.a"
 end
 
link "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop/lib/native/libgplcompression.so" do
   to "/usr/lib/hadoop/lib/native/Linux-amd64-64/libgplcompression.so.0.0.0"
end
 
link "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop/lib/native/liblzo2.so" do
  to "/usr/lib/x86_64-linux-gnu/liblzo2.so.2.0.0"
end

# Install YARN Bits
template "/etc/hadoop/conf/container-executor.cfg" do
  source "hdp_container-executor.cfg.erb"
  owner "root"
  group "yarn"
  mode "0400"
  variables(:mounts => node[:bcpc][:hadoop][:mounts])
  action :create
  notifies :run, "bash[verify-container-executor]", :immediate
end

bash "verify-container-executor" do
  code "/usr/lib/hadoop-yarn/bin/container-executor --checksetup"
  group "yarn"
  action :nothing
  only_if { File.exists?("/usr/lib/hadoop-yarn/bin/container-executor") }
end

# Install Sqoop Bits
template "/etc/sqoop/conf/sqoop-env.sh" do
  source "sq_sqoop-env.sh.erb"
  mode "0444"
  action :create
end

# Setup nodemanager bits
link "/etc/init.d/hadoop-yarn-nodemanager" do
  to "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop-yarn/etc/#{node["platform_family"] == 'rhel' ? "rc.d/" : ""}init.d/hadoop-yarn-nodemanager"
end

# Build nodes for YARN log storage
node[:bcpc][:hadoop][:mounts].each do |i|
  directory "/disk/#{i}/yarn/" do
    owner "yarn"
    group "yarn"
    mode 0755
    action :create
  end
  %w{mapred-local local logs}.each do |d|
    directory "/disk/#{i}/yarn/#{d}" do
      owner "yarn"
      group "hadoop"
      mode 0755
      action :create
    end
  end
end

yarn_dep = ["template[/etc/hadoop/conf/hadoop-env.sh]",
            "template[/etc/hadoop/conf/yarn-env.sh]",
            "template[/etc/hadoop/conf/yarn-site.xml]",
            "bash[hdp-select hadoop-yarn-nodemanager]",
            "user_ulimit[yarn]"]

hadoop_service "hadoop-yarn-nodemanager" do
  dependencies yarn_dep
  process_identifier "org.apache.hadoop.yarn.server.nodemanager.NodeManager"
end

