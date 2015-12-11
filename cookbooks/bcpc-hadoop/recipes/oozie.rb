include_recipe 'bcpc-hadoop::oozie_config'
::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

(%w{libmysql-java zip unzip extjs hadoop-lzo} +
 %w{oozie-server oozie-client}.map{|p| hwx_pkg_str(p, node[:bcpc][:hadoop][:distribution][:release])}).each do |pkg|
  package pkg do
    action :upgrade
  end
end
%w{oozie-server oozie-client}.each do |pkg|
  bash "hdp-select #{pkg}" do
    code "hdp-select set #{pkg} #{node[:bcpc][:hadoop][:distribution][:release]}"
    subscribes :run, "package[#{hwx_pkg_str(pkg, node[:bcpc][:hadoop][:distribution][:release])}]", :immediate
    action :nothing
  end
end

OOZIE_LIB_PATH="/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/oozie"
OOZIE_CLIENT_PATH='/usr/hdp/current/oozie-client'
OOZIE_SERVER_PATH="/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/oozie-server/oozie-server"
OOZIE_SERVER_PATH="/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/oozie-server"
OOZIE_SHARELIB_TARBALL_PATH="/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/oozie/oozie-sharelib.tar.gz"
HDFS_URL=node[:bcpc][:hadoop][:hdfs_url]

directory "#{OOZIE_LIB_PATH}/libext" do
  owner "oozie"
  group "oozie"
  mode 00755
  action :create
  recursive true
end

directory "/var/run/oozie" do
  owner "oozie"
  group "oozie"
  mode 00755
  action :create
  recursive true
end

#bash "copy hadoop libs" do
#  src_dir="/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/hadoop/lib"
#  dst_dir="#{OOZIE_LIB_PATH}/libext/"
#  code "for f in `ls *.jar`; do ln -s #{src_dir}/$f #{dst_dir}/$f; done"
#  cwd src_dir
#  user "oozie"
#  # check if all source files are in destination directory
#  not_if { (::Dir.entries("#{src_dir}") - ::Dir.entries("#{dst_dir}")).empty? }
#end

["/usr/share/HDP-oozie/ext-2.2.zip",
 "/usr/share/java/mysql-connector-java.jar",
 "/usr/lib/hadoop/lib/hadoop-lzo-0.6.0.jar"].each do |path|
  link "#{OOZIE_LIB_PATH}/libext/#{File.basename(path)}" do
    to path
  end
end

bash "copy" do
  code "cp -r /usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/oozie/tomcat-deployment/conf/ssl /usr/hdp/current/oozie-server/conf/"
end

service "stop-oozie-for-war-setup" do
  action :stop
  supports :status => true, :restart => true, :reload => false
  service_name "oozie"
  supports :status => true, :restart => true, :reload => false
  only_if {
    not File.exists?("#{OOZIE_SERVER_PATH}/webapps/oozie.war") or
    File.mtime("#{OOZIE_CLIENT_PATH}/libext/") >
      File.mtime("#{OOZIE_SERVER_PATH}/webapps/oozie.war")
  }
end

bash "oozie_setup_war" do
  code "#{OOZIE_CLIENT_PATH}/bin/oozie-setup.sh prepare-war"
  returns [0]
  only_if {
    not File.exists?("#{OOZIE_SERVER_PATH}/webapps/oozie.war") or
    File.mtime("#{OOZIE_CLIENT_PATH}/libext/") >
      File.mtime("#{OOZIE_SERVER_PATH}/webapps/oozie.war")
  }
end

directory "/etc/oozie/conf.#{node.chef_environment}/action-conf" do
  owner "root"
  group "root"
  mode 00755
  action :create
  recursive true
end

directory "/etc/oozie/conf.#{node.chef_environment}/hadoop-conf" do
  owner "root"
  group "root"
  mode 00755
  action :create
  recursive true
end

bash "make_oozie_user_dir" do
  code <<-EOH
    hdfs dfs -mkdir -p #{HDFS_URL}/user/oozie && \
    hdfs dfs -chown -R oozie #{HDFS_URL}/user/oozie
  EOH
  user "hdfs"
  not_if "hdfs dfs -test -d #{HDFS_URL}/user/oozie", :user => "hdfs"
end

bash "oozie_create_shared_libs" do
  code "#{OOZIE_CLIENT_PATH}/bin/oozie-setup.sh sharelib create -fs #{HDFS_URL} -locallib #{OOZIE_SHARELIB_TARBALL_PATH}"
  user "oozie"
  not_if {
    require 'digest'
    chksum = node[:bcpc][:hadoop][:oozie][:sharelib_checksum]
    not chksum.nil? and Digest::MD5.hexdigest(File.read(OOZIE_SHARELIB_TARBALL_PATH)) == chksum
  } 
  only_if "echo 'test'| hdfs dfs -copyFromLocal - /tmp/oozie-test && hdfs dfs -rm -skipTrash /tmp/oozie-test", :user => "hdfs"
  notifies :run, "ruby_block[update_sharelib_checksum]", :immediately
end

ruby_block "update_sharelib_checksum" do
  block do
    require 'digest'
    node.set[:bcpc][:hadoop][:oozie][:sharelib_checksum] = 
      Digest::MD5.hexdigest(File.read(OOZIE_SHARELIB_TARBALL_PATH))
  end
  action :nothing
  notifies :run, "ruby_block[notify_sharelib_update]", :immediately
end

ruby_block "notify_sharelib_update" do
  block do
    node[:bcpc][:hadoop][:oozie_hosts].each do |oozie_host|
      update_oozie_sharelib(float_host(oozie_host[:hostname]))
    end
  end
  action :nothing
end

template "/etc/oozie/conf.#{node.chef_environment}/action-conf/hive.xml" do
  mode 0644
  source "ooz_action_hive.xml.erb"
end

file "#{OOZIE_CLIENT_PATH}/oozie.sql" do
  owner "oozie"
  group "oozie"
end

ruby_block "oozie-database-creation" do
  cmd = "mysql -uroot -p#{get_config!('password','mysql-root','os')} -e"
  privs = "CREATE,INDEX,SELECT,INSERT,UPDATE,DELETE,LOCK TABLES,EXECUTE"
  block do
    if not system " #{cmd} 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"oozie\"' | grep oozie" then
      code = <<-EOF
        CREATE DATABASE oozie;
        GRANT #{privs} ON oozie.* TO 'oozie'@'%' IDENTIFIED BY '#{get_config('mysql-oozie-password')}';
        GRANT #{privs} ON oozie.* TO 'oozie'@'localhost' IDENTIFIED BY '#{get_config('mysql-oozie-password')}';
        FLUSH PRIVILEGES;
      EOF
      IO.popen("mysql -uroot -p#{get_config!('password','mysql-root','os')}", "r+") do |db|
        db.write code
      end
      system "sudo -u oozie /usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/oozie/bin/ooziedb.sh create -sqlfile /usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/oozie/oozie.sql -run Validate DB Connection"
      self.resolve_notification_references
    end
  end
end

link '/etc/init.d/oozie' do
  to "/usr/hdp/#{node[:bcpc][:hadoop][:distribution][:release]}/oozie/etc/init.d/oozie-server"
end

service "generally run oozie" do
  action [:enable, :start]
  service_name "oozie"
  supports :status => true, :restart => true, :reload => false
  subscribes :restart, "template[/etc/oozie/conf/oozie-site.xml]", :delayed
  subscribes :restart, "template[/etc/oozie/conf/oozie-env.sh]", :delayed
  subscribes :restart, "bash[hdp-select oozie-server]", :delayed
end

ruby_block "Oozie Down" do
  i = 0
  block do
    while not oozie_running?(float_host(node[:fqdn])) 
      if i < 10
        sleep(0.5)
        i += 1
        Chef::Log.debug("Oozie is down - #{status}")
      else
        Chef::Application.fatal! "Oozie is reported as down for more than 5 seconds -- #{status}"
        raise
      end
    end
    Chef::Log.debug("Oozie is up")
  end
  not_if { oozie_running?(float_host(node[:fqdn])) }
end
