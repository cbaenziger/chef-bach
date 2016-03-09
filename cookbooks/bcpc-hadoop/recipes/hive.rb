#
# Cookbook Name : bcpc-hadoop
# Recipe Name : hive
# Description : To install hive/hcatalog core packages

include_recipe "bcpc-hadoop::hive_config"
::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

# Install Hive Bits
# workaround for hcatalog dpkg not creating the hcat user it requires
user "hcat" do 
  username "hcat"
  system true
  shell "/bin/bash"
  home "/usr/lib/hcatalog"
  supports :manage_home => false
  not_if { user_exists? "hcat" }
end

%w{hive hcatalog hive-hcatalog}.each do |pkg|
  package hwx_pkg_str(pkg, node[:bcpc][:hadoop][:distribution][:release], node[:platform_family]) do
    action :install
  end

  bash "hdp-select pkg" do
    code "hdp-select set hive-webhcat #{node[:bcpc][:hadoop][:distribution][:release]}"
    subscribes :run, "package[#{hwx_pkg_str(pkg, node[:bcpc][:hadoop][:distribution][:release], node[:platform_family])}]", :immediate
    action :nothing
  end
end

link "/usr/hdp/current/hive-metastore/lib/mysql-connector-java.jar" do
  to "/usr/share/java/mysql-connector-java.jar"
end

link "/usr/hdp/current/hive-server2/lib/mysql-connector-java.jar" do
  to "/usr/share/java/mysql-connector-java.jar"
end

#template "hive-config" do
#  path "/usr/lib/hive/bin/hive-config.sh"
#  source "hv_hive-config.sh.erb"
#  owner "root"
#  group "root"
#  mode "0755"
#end
