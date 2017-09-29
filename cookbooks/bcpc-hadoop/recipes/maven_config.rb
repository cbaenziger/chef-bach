#
# Cookbook Name:: bcpc-hadoop
# Recipe:: maven_config
#
# Copyright 2017, Bloomberg Finance L.P.
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

cert_dir = '/usr/local/share/ca-certificates'

include_recipe 'bcpc::proxy_configuration' if node['bcpc']['bootstrap']['proxy']

if ::Dir.exist?(cert_dir)
  kstore = node['bcpc']['hadoop']['java_https_keystore']
  node.override['maven']['mavenrc']['opts'] = \
    node['maven']['mavenrc']['opts'] +
    ' -Djavax.net.ssl.trustStorePassword=doesnotneedtobesecure' \
    " -Djavax.net.ssl.trustStore=#{kstore}"
end

maven_file = Pathname.new(node['maven']['url']).basename

# Dependencies of the maven cookbook.
%w(gyoku nori).each do |gem_name|
  bcpc_chef_gem gem_name do
    compile_time true
  end
end

unified_certs = ::File.join(Chef::Config['file_cache_path'], 'ca-certs.pem')

# download Maven only if not already stashed in the bins directory
if node['fqdn'] == get_bootstrap
  internet_download_url = node['maven']['url']
  remote_file "/home/vagrant/chef-bcpc/bins/#{maven_file}" do
    source internet_download_url
    action :create
    mode 0o0555
    checksum node['maven']['checksum']
  end
else
  node.override['maven']['url'] = File.join(get_binary_server_url, maven_file)
end

include_recipe 'maven::default'

# handling for custom SSL certificates
custom_certs = Find.find(cert_dir).select { |f| ::File.file?(f) }
unless custom_certs.empty?
  file 'cacert file' do
    cert_data = custom_certs.map { |f| File.open(f, 'r').read }.join("\n")
    path unified_certs
    content lazy { cert_data }
    action :create
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

maven_settings 'settings.proxies' do
  uri = URI(node['bcpc']['bootstrap']['proxy'])
  value proxy: {
    active: true,
    protocol: uri.scheme,
    host: uri.host,
    port: uri.port,
    nonProxyHosts: 'localhost|127.0.0.1|localaddress|.localdomain.com'
  }
  only_if { !node['bcpc']['bootstrap']['proxy'].nil? }
end

# it looks like the Maven cookbook uses the default
# restrictive umask from Chef-Client
execute 'chmod maven' do
  command "chmod -R 755 #{node['maven']['m2_home']}"
end
