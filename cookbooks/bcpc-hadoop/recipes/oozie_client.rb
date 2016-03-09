# Cookbook Name : bcpc-hadoop
# Recipe Name : oozie_client
# Description : To setup oozie-client

include_recipe 'bcpc-hadoop::oozie_config'
::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

package hwx_pkg_str("oozie-client", node[:bcpc][:hadoop][:distribution][:release], node[:platform_family]) do
   action :upgrade
end
bash "hdp-select oozie-client" do
  code "hdp-select set oozie-client #{node[:bcpc][:hadoop][:distribution][:release]}"
  subscribes :run, "package[#{hwx_pkg_str("oozie-client", node[:bcpc][:hadoop][:distribution][:release], node[:platform_family])}]", :immediate
  action :nothing
end
