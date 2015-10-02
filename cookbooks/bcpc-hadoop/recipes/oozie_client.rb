# Cookbook Name : bcpc-hadoop
# Recipe Name : oozie_client
# Description : To setup oozie-client

include_recipe 'bcpc-hadoop::oozie_config'

package "oozie-client" do
   action :upgrade
end
bash "hdp-select oozie-client" do
  code "hdp-select set oozie-client #{node[:bcpc][:hadoop][:distribution][:release]}"
  subscribes :run, "package[oozie-client]", :immediate
  action :nothing
end
