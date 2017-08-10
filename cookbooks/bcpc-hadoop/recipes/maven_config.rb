require 'pathname'

node.override['maven']['install_java'] = false

if ::Dir.exist?('/usr/local/share/ca-certificates')
  node.override['maven']['mavenrc']['opts'] = \
    node['maven']['mavenrc']['opts'] +\
    " -Djavax.net.ssl.trustStorePassword=doesnotneedtobesecure " + \
    "-Djavax.net.ssl.trustStore=#{node['bcpc']['hadoop']['java_https_keystore']}"
end

internet_download_url = node['maven']['url']
maven_file = Pathname.new(node['maven']['url']).basename

node.override['maven']['url'] = "#{get_binary_server_url}/#{maven_file}"

unified_certs = ::File.join(Chef::Config[:file_cache_path], 'ca-certs.pem')

# download Maven only if not already stashed in the bins directory
remote_file "/home/vagrant/chef-bcpc/bins/#{maven_file}" do
  source internet_download_url
  action :create
  mode 0555
  checksum node['maven']['checksum']
end

file 'cacert file' do
  cert_data = Dir.glob('/usr/local/share/ca-certificates/*').map do |cert|
    File.open(cert, 'r').read()
  end.join("\n")
  path unified_certs 
  content lazy { cert_data }
  action :create
  only_if { ::Dir.exist?('/usr/local/share/ca-certificates') }
  notifies :delete, 'file[keystore file]', :immediately
  notifies :run, 'execute[create keystore]', :immediately
end

file 'keystore file' do
  path node['bcpc']['hadoop']['java_https_keystore']
  action :nothing
end

execute 'create keystore' do
  command <<-EOH
    yes | keytool -v -alias mavensrv -import \
    -file #{unified_certs} \
    -keystore #{node['bcpc']['hadoop']['java_https_keystore']} \
    -storepass doesnotneedtobesecure \
    -alias mavensrv -import
    EOH
  action :nothing
end

if ::Dir.exist?('/usr/local/share/ca-certificates')
  node.override['maven']['mavenrc']['opts'] = <<-EOH
    #{node['maven']['mavenrc']['opts']} \
    -Djavax.net.ssl.trustStore=#{node['bcpc']['hadoop']['java_https_keystore']} \
    -Djavax.net.ssl.trustStorePassword=doesnotneedtobesecure
  EOH
end

# Setup custom maven config
directory '/root/.m2' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

include_recipe 'maven::settings'

maven_settings "settings.proxies" do
  uri = URI(node[:bcpc][:bootstrap][:proxy])
  value proxy: {
    active: true,
    protocol: uri.scheme,
    host: uri.host,
    port: uri.port,
    nonProxyHosts: 'localhost|127.0.0.1|localaddress|.localdomain.com'
  }
  only_if { node[:bcpc][:bootstrap][:proxy] != nil }
end

include_recipe 'maven::default'

# it looks like the Maven cookbook uses the default, restrictive umask from Chef-Client
execute 'chmod maven' do
  command "chmod -R 755 #{node['maven']['m2_home']}"
end
