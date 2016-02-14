require 'base64'
include_recipe 'bcpc-hadoop::hadoop_config'
::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
::Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

%w{hadoop-hdfs-namenode hadoop-hdfs-journalnode}.each do |pkg|
  package hwx_pkg_str(pkg, node[:bcpc][:hadoop][:distribution][:release]) do
    action :install
  end
  hdp_select(pkg, node[:bcpc][:hadoop][:distribution][:active_release])
end

if get_config("namenode_txn_fmt") then
  file "#{Chef::Config[:file_cache_path]}/nn_fmt.tgz" do
    user "hdfs"
    group "hdfs"
    user 0644
    content Base64.decode64(get_config("namenode_txn_fmt"))
    not_if { node[:bcpc][:hadoop][:mounts].all? { |d| File.exists?("/disk/#{d}/dfs/jn/#{node.chef_environment}/current/VERSION") } }
  end
end

node[:bcpc][:hadoop][:mounts].each do |d|

end
