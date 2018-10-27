default['bach']['repository']['chefdk']['url'] = \
  'https://packages.chef.io/files/stable/chefdk/2.4.17/ubuntu/' \
  '16.04/chefdk_2.4.17-1_amd64.deb'
default['bach']['repository']['chefdk']['sha256'] = \
  '15c40af26358ba6b1be23d5255b49533fd8e5421f7afbc716dcb94384b92e1b0'
default['bach']['repository']['chef']['url'] = \
  'https://packages.chef.io/repos/apt/stable/ubuntu/' \
  '16.04/chef_12.22.5-1_amd64.deb'
default['bach']['repository']['chef']['sha256'] = \
  '10531deefe1a46f300b5179887a1d27489f54418c08489b98d67618c2a54e6ce'
# it does not appear that there is a 14.04 version of the ancient Chef-Server we use
default['bach']['repository']['chef_server']['url'] = \
  'https://packages.chef.io/files/stable/chef-server/12.18.14/' \
  'ubuntu/16.04/chef-server-core_12.18.14-1_amd64.deb'
default['bach']['repository']['chef_server']['sha256'] = \
  '2be59db9ac71c5595ffd605e96de81fc3ef36aa4756fa73b2be9a53edbfce809'
default['bach']['repository']['chef_url_base'] = 'https://packages.chef.io/repos/apt/stable/ubuntu/16.04/'
default['bach']['repository']['chef_server_ip'] = '127.0.0.1'
default['bach']['repository']['chef_server_fqdn'] = 'localhost'
