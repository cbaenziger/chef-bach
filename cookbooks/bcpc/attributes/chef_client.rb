#
# Cookbook Name:: bcpc
# File:: attributes/chef_client.rb
#
# This file contains configuration for the chef-client cookbook, to
# ensure both bootstrap and client nodes configure chef correctly.
#
sudo_user = ENV['SUDO_USER'] || 'vagrant'

default['chef_client']['config'].tap do |config|
  config['log_level'] = ':info'
  config['log_location'] = 'STDOUT'
  config['node_name'] = node[:fqdn]
  config['client_name'] = node[:fqdn]
  config['client_key'] = '/etc/chef/client.pem'
  config['chef_server_url'] =
    if node[:fqdn] == get_bootstrap
      "https://#{node[:bcpc][:bootstrap][:server]}"
    else
      "https://#{node[:bcpc][:bootstrap][:vip]}"
    end

  if node[:fqdn] == get_bootstrap
    config['syntax_check_cache_path'] =
      "/home/#{sudo_user}/chef-bcpc/.chef/syntax_check_cache"
    
    config['cookbook_path'] =
      "/home/#{sudo_user}/chef-bcpc/vendor/cookbooks"
  end
end

#
# The size of the result set on a host bound to a directory service
# will cause chef-client runs to fail to upload the node object.
#
# The solution is to disable the passwd plugin, so users are not
# recorded on the chef server.
#
default['ohai']['disabled_plugins'] = [ 'passwd' ]
