#
#  Installing Hive & Hcatalog
#
include_recipe "bcpc-hadoop::hive_config"
include_recipe "bcpc-hadoop::hive_table_stat"
::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

%W{#{hwx_pkg_str("hive-hcatalog", node[:bcpc][:hadoop][:distribution][:release])}
   hadoop-lzo
   libmysql-java}.each do |pkg|
  package pkg do
    action :upgrade
  end
end

bash "hdp-select hive-metastore" do
  code "hdp-select set hive-metastore #{node[:bcpc][:hadoop][:distribution][:release]}"
  subscribes :run, "package[#{hwx_pkg_str("hive-hcatalog", node[:bcpc][:hadoop][:distribution][:release])}]", :immediate
  action :nothing
end

bash "hdp-select hive-server2" do
  code "hdp-select set hive-server2 #{node[:bcpc][:hadoop][:distribution][:release]}"
  subscribes :run, "package[#{hwx_pkg_str("hive-hcatalog", node[:bcpc][:hadoop][:distribution][:release])}]", :immediate
  action :nothing
end

user_ulimit "hive" do
  filehandle_limit 32769
  process_limit 65536
end

link "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop/lib/hadoop-lzo-0.6.0.jar" do
  to "/usr/lib/hadoop/lib/hadoop-lzo-0.6.0.jar"
end

bash "create-hive-user-home" do
  code <<-EOH
  hdfs dfs -mkdir -p /user/hive
  hdfs dfs -chmod 1777 /user/hive
  hdfs dfs -chown hive:hdfs /user/hive
  EOH
  user "hdfs"
end

bash "create-hive-warehouse" do
  code <<-EOH
  hdfs dfs -mkdir -p /apps/hive/warehousehadoop
  hdfs dfs -chmod -R 775 /apps/hive
  hdfs dfs -chown -R hive:hdfs /apps/hive
  EOH
  user "hdfs"
end

bash "create-hive-scratch" do
  code <<-EOH
  hdfs dfs -mkdir -p /tmp/scratch
  hdfs dfs -chmod -R 1777 /tmp/scratch
  hdfs dfs -chown -R hive:hdfs /tmp/scratch
  EOH
  user "hdfs"
end

ruby_block "hive-metastore-database-creation" do
  cmd = "mysql -uroot -p#{get_config!('password','mysql-root','os')} -e"
  privs = "SELECT,INSERT,UPDATE,DELETE,LOCK TABLES,EXECUTE" # todo node[:bcpc][:hadoop][:hive_db_privs].join(",")
  block do
    if not system " #{cmd} 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"metastore\"' | grep -q metastore" then
      code = <<-EOF
        CREATE DATABASE metastore;
        GRANT #{privs} ON metastore.* TO 'hive'@'%' IDENTIFIED BY '#{get_config('mysql-hive-password')}';
        GRANT #{privs} ON metastore.* TO 'hive'@'localhost' IDENTIFIED BY '#{get_config('mysql-hive-password')}';
        FLUSH PRIVILEGES;
        USE metastore;
        SOURCE /usr/hdp/current/hive-metastore/scripts/metastore/upgrade/mysql/hive-schema-0.14.0.mysql.sql;
        EOF
      IO.popen("mysql -uroot -p#{get_config!('password','mysql-root','os')}", "r+") do |db|
        db.write code
      end
      self.notifies :enable, "service[hive-metastore]", :delayed
      self.resolve_notification_references
    end
  end
end

#bash "create-hive-metastore-db" do
#  code <<-EOH
#  /usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hive/bin/schematool -initSchema -dbType mysql -verbose
#  EOH
#end

template "/etc/init.d/hive-metastore" do
  source "hdp_hive-metastore-initd.erb"
  mode 0655
end

template "/etc/init.d/hive-server2" do
  source "hdp_hive-server2-initd.erb"
  mode 0655
end

directory "/var/log/hive/gc" do
  action :create
  mode 0755
  user "hive"
end

service "hive-metastore" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/hive/conf/hive-site.xml]", :delayed
  subscribes :restart, "template[/etc/hive/conf/hive-log4j.properties]", :delayed
  subscribes :restart, "bash[hdp-select hive-hcatalog]", :delayed
  subscribes :restart, "directory[/var/log/hive/gc]", :delayed
end

service "hive-server2" do
  action [:enable, :start]
  supports :status => true, :restart => true, :reload => false
  subscribes :restart, "template[/etc/hive/conf/hive-site.xml]", :delayed
  subscribes :restart, "template[/etc/hive/conf/hive-log4j.properties]", :delayed
  subscribes :restart, "directory[/var/log/hive/gc]", :delayed
end
