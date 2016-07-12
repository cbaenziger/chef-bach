node.override[:bcpc][:management][:vip] = get_all_nodes.select{|s| s.hostname.include? 'bcpc-1'}[0]['openstack']['local_ipv4']
puts "XXX_Clay #{get_all_nodes.select{|s| s.hostname.include? 'bcpc-1'}[0]['openstack']['local_ipv4']}"
node.override[:bcpc][:floating][:vip] = get_all_nodes.select{|s| s.hostname.include? 'bcpc-1'}[0]['openstack']['local_ipv4']
puts "XXX_Clay #{node[:bcpc][:floating][:vip]}"

