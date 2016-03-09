::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)

[hwx_pkg_str("pig", node[:bcpc][:hadoop][:distribution][:release], node[:platform_family]), "jython"].each do |pkg|
  package pkg do
    action :upgrade
  end
end
