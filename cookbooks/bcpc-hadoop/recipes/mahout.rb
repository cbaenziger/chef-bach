::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

package hwx_pkg_str("mahout", node[:bcpc][:hadoop][:distribution][:release], node[:platform_family])
bash "hdp-select mahout-client" do
  code "hdp-select set mahout-client #{node[:bcpc][:hadoop][:distribution][:release]}"
  subscribes :run, "package[#{hwx_pkg_str("mahout-client", node[:bcpc][:hadoop][:distribution][:release], node[:platform_family])}]", :immediate
  action :nothing
end
