package "libmysql-java" do
  action :upgrade
end

link "/usr/lib/hive/lib/mysql.jar" do
  to "/usr/share/java/mysql.jar"
end

%w{hive-hcatalog hive-hcatalog-server hive-webhcat}.each do |p|
  package p do
    action :upgrade
  end
end
%w{hive-metastore hive-webhcat hive-server2}.each do |comp|
  bash "hdp-select #{comp}" do
    code "hdp-select set #{comp} #{node[:bcpc][:hadoop][:distribution][:release]}"
    subscribes :run, "package[#{comp}]", :immediate
    action :nothing
  end
end

%w{hive-hcatalog-server}.each do |s|
  service s do
    action [:enable, :start]
    supports :status => true, :restart => true, :reload => false
    subscribes :restart, "template[/etc/webhcat/conf/webhcat-site.xml]", :delayed
    subscribes :restart, "template[/etc/hive/conf/hive-site.xml]", :delayed
    subscribes :restart, "bash[hdp-select hive-metastore]", :delayed
  end
end
