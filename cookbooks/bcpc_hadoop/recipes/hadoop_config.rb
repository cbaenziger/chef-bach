#
# Cookbook Name:: bcpc_hadoop
# Recipe:: hadoop_config
#
# Copyright 2014, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

directory "/etc/hadoop/conf.#{node.chef_environment}" do
  owner "root"
  group "root"
  mode 00755
  recursive true
  action :create
end

bash "update-hadoop-conf-alternatives" do
  code %Q{
    update-alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.#{node.chef_environment} 50
    update-alternatives --set hadoop-conf /etc/hadoop/conf.#{node.chef_environment}
  }
end

hadoop_conf_files = %w{capacity-scheduler.xml
   core-site.xml
   fair-scheduler.xml
   hadoop-metrics2.properties
   hadoop-metrics.properties
   hadoop-policy.xml
   hdfs-site.xml
   log4j.properties
   mapred-site.xml
   slaves
   ssl-client.xml
   ssl-server.xml
   yarn-site.xml
   mapred.exclude
   dfs.exclude
}
node[:bcpc][:hadoop][:hdfs][:HA] == true and hadoop_conf_files.insert(-1,"hdfs-site_HA.xml")

hadoop_conf_files.each do |t|
   template "/etc/hadoop/conf/#{t}" do
     source "hdp_#{t}.erb"
     mode 0644
     variables(:nn_hosts => node[:bcpc][:hadoop][:nn_hosts],
               :zk_hosts => node[:bcpc][:hadoop][:zookeeper][:servers],
               :jn_hosts => node[:bcpc][:hadoop][:jn_hosts],
               :rm_hosts => node[:bcpc][:hadoop][:rm_hosts],
               :dn_hosts => node[:bcpc][:hadoop][:dn_hosts],
               :hs_hosts => node[:bcpc][:hadoop][:hs_hosts],
               :mounts => node[:bcpc][:hadoop][:mounts])
   end
end

%w{yarn-env.sh
  hadoop-env.sh}.each do |t|
 template "/etc/hadoop/conf/#{t}" do
   source "hdp_#{t}.erb"
   mode 0644
   variables(:nn_hosts => node[:bcpc][:hadoop][:nn_hosts],
             :zk_hosts => node[:bcpc][:hadoop][:zookeeper][:servers],
             :jn_hosts => node[:bcpc][:hadoop][:jn_hosts],
             :mounts => node[:bcpc][:hadoop][:mounts],
             :nn_jmx_port => node[:bcpc][:hadoop][:namenode][:jmx][:port],
             :dn_jmx_port => node[:bcpc][:hadoop][:datanode][:jmx][:port]
   )
 end
end

package "openjdk-7-jdk" do
    action :upgrade
end
