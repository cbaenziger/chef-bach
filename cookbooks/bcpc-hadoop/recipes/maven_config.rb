require 'pathname'

node.override['maven']['install_java'] = false

if ::Dir.exist?('/usr/local/share/ca-certificates')
  node.override['maven']['mavenrc']['opts'] = \
    node['maven']['mavenrc']['opts'] +\
    " -Djavax.net.ssl.trustStorePassword=doesnotneedtobesecure " + \
    "-Djavax.net.ssl.trustStore=#{node['bccp']['hadoop']['java_https_keystore']}"
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

# Setup keystore for custom certs
ruby_block 'concatenate certs' do
  block do
    File.open(unitifed_certs, 'w' ) do |output|
      Dir.glob('/usr/local/share/ca-certificates/*').each do |cert|
        File.open(cert) do |cert_data|
          cert_data.each { |line| output.puts(line) }
        end
      end
    end
  end
  only_if { ::Dir.exist?('/usr/local/share/ca-certificates') }
  notifies :run, 'directory["create keystore"]', :immediately
end

execute 'create keystore' do
  command <<<-EOH
    keytool -v -alias mavensrv -import \
    -file #{unified_certs} \
    -keystore #{node['bccp']['hadoop']['java_https_keystore']}
    -storepass doesnotneedtobesecure
    -alias mavensrv -import
    EOH
  action :nothing
end

# Setup custom maven config
directory '/root/.m2' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

template "maven_settings.xml" do
  path '/root/.m2/settings.xml'
  source 'maven_settings.xml.erb'
  owner 'root' 
  group 'root'
  mode '0644'
end
