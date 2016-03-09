include_recipe 'bcpc-hadoop::hbase_config'
::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

node.default['bcpc']['hadoop']['copylog']['region_server'] = {
    'logfile' => "/var/log/hbase/hbase-hbase-0-regionserver-#{node.hostname}.log", 
    'docopy' => true
}

node.default['bcpc']['hadoop']['copylog']['region_server_out'] = {
    'logfile' => "/var/log/hbase/hbase-hbase-0-regionserver-#{node.hostname}.out", 
    'docopy' => true
}

(%w{libsnappy1} +
 %w{hbase hbase-regionserver phoenix}.map{|p| hwx_pkg_str(p, node[:bcpc][:hadoop][:distribution][:release], node[:platform_family])}).each do |pkg|
  package pkg do
    action :upgrade
  end
end

%w{hbase-client hbase-regionserver phoenix-client}.each do |pkg|
  bash "hdp-select #{pkg}" do
    code "hdp-select set #{pkg} #{node[:bcpc][:hadoop][:distribution][:release]}"
    subscribes :run, "package[#{hwx_pkg_str(pkg, node[:bcpc][:hadoop][:distribution][:release], node[:platform_family])}]", :immediate
    action :nothing
  end
end

user_ulimit "hbase" do
  filehandle_limit 32769
end

directory "/usr/hdp/current/hbase-regionserver/lib/native/Linux-amd64-64" do
  recursive true
  action :create
end

link "/usr/hdp/current/hbase-regionserver/lib/native/Linux-amd64-64/libsnappy.so" do
  to "/usr/lib/libsnappy.so.1"
end

template "/etc/default/hbase" do
  source "hdp_hbase.default.erb"
  mode 0655
  variables(:hbrs_jmx_port => node[:bcpc][:hadoop][:hbase_rs][:jmx][:port])
end

#link "/etc/init.d/hbase-regionserver" do
#  to "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hbase/etc/#{node["platform_family"] == 'rhel' ? "rc.d/" : ""}init.d/hbase-regionserver"
#end

template "/etc/init.d/hbase-regionserver" do
  source "hdp_hbase-regionserver-initd.erb"
  mode 0655
end

rs_service_dep = ["template[/etc/hbase/conf/hbase-site.xml]",
                  "template[/etc/hbase/conf/hbase-policy.xml]",
                  "template[/etc/hbase/conf/hbase-env.sh]",
                  "template[/etc/hadoop/conf/hdfs-site.xml]",
                  "user_ulimit[hbase]",
                  "bash[hdp-select hbase-regionserver]"]

hadoop_service "hbase-regionserver" do
  dependencies rs_service_dep
  process_identifier "org.apache.hadoop.hbase.regionserver.HRegionServer"
end
