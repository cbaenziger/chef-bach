default['bach']['repository']['chefdk']['url'] = \
  'https://packages.chef.io/files/stable/chefdk/2.6.2/ubuntu/' \
  '18.04/chefdk_2.6.2-1_amd64.deb'
default['bach']['repository']['chefdk']['sha256'] = \
  'd970187a9061c2c1672a07d3690796eacfe6bddce7bbc2eba30afad3e3fba664'
default['bach']['repository']['chef']['url'] = \
  'https://packages.chef.io/files/current/chef/12.22.6/ubuntu/' \
  '18.04/chef_12.22.6-1_amd64.deb'
default['bach']['repository']['chef']['sha256'] = \
  '6ad84f6fa2df587ef9fe1f62d56b7bb85306b8a1a0c4aaf62476d95337133681'
# it does not appear that there is a 14.04 version of the ancient Chef-Server we use
default['bach']['repository']['chef_server']['url'] = \
  'https://packages.chef.io/files/current/chef-server/12.18.14/' \
  'ubuntu/18.04/chef-server-core_12.18.14-1_amd64.deb'
default['bach']['repository']['chef_server']['sha256'] = \
  '2be59db9ac71c5595ffd605e96de81fc3ef36aa4756fa73b2be9a53edbfce809'
default['bach']['repository']['chef_url_base'] = 'https://packages.chef.io/repos/apt/stable/ubuntu/18.04/'
default['bach']['repository']['chef_server_ip'] = '127.0.0.1'
default['bach']['repository']['chef_server_fqdn'] = 'localhost'
