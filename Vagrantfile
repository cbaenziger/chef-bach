# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# This is a Vagrantfile to automatically provision a bootstrap node
# with a Chef server.
#
# See http://www.vagrantup.com/ for info on Vagrant.
#

require 'json'
require 'ipaddr'

#
# You can override parts of the vagrant config by creating a
# 'Vagrantfile.local.rb'
#
# (You may find this useful for SSL certificate injection.)
#
local_file =
  if File.basename(File.expand_path('.')) == 'vbox'
    File.expand_path('../Vagrantfile.local.rb')
  else
    "#{__FILE__}.local.rb"
  end

if File.exist?(local_file)
  if ENV['BACH_DEBUG']
    $stderr.puts "Found #{local_file}, including"
  end
  require local_file
end

#
# Since we run vagrant commands from ~/chef-bcpc and from
# ~/chef-bcpc/vbox directory, finding correct location for environment
# file is important.
#
# To set the base_dir correct we check if we are inside "vbox"
# directory or not and act accordingly
#

base_dir = if File.basename(File.expand_path('.')) == 'vbox'
             File.expand_path('../environments')
           else
             File.expand_path('./environments')
           end

if ENV['BACH_DEBUG']
  $stderr.puts "Base directory is : #{base_dir}"
end

json_file = Dir[File.join("#{base_dir}/../environments/", '*.json')]

if json_file.empty?
  $stderr.puts 'No environment file found to parse. ' \
    'Please make sure at least one environment file exists.'
  exit
end

if json_file.length > 1
  $stderr.puts 'More than one environment file found.'
  exit
end

chef_env = JSON.parse(File.read(json_file.join(',')))

cluster_environment = chef_env['name']

cname = chef_env['override_attributes']['bcpc'].has_key?('cluster_name') && \
  chef_env['override_attributes']['bcpc']['cluster_name'] || ''

bootstrap_hostname =
  cname + chef_env['override_attributes']['bcpc']['bootstrap']['hostname']

bootstrap_domain =
  chef_env['override_attributes']['bcpc']['domain_name'] || 'bcpc.example.com'

# Management IP, Float IP, Storage IP
rack = chef_env['override_attributes']['bcpc']['networks'].keys.first
network_json = chef_env['override_attributes']['bcpc']['networks'][rack]
management_net =
  IPAddr.new(network_json['management']['cidr'] || '10.0.100.0/24')
float_net =
  IPAddr.new(network_json['floating']['cidr'] || '192.168.100.0/24')
storage_net =
  IPAddr.new(network_json['storage']['cidr'] || '172.16.100.0/24')

# We rely on global variables to deal with Vagrantfile scoping rules.
# rubocop:disable Style/GlobalVars
$bach_local_environment = cluster_environment
$bach_local_mirror = nil

Vagrant.configure('2') do |config|
  config.vm.define "#{cname}bootstrap".to_sym do |bootstrap|
    bootstrap.vm.hostname = "#{cname}#{bootstrap_hostname}.#{bootstrap_domain}"

    # Awaiting https://github.com/ruby/ruby/pull/1269 to properly retrieve mask
    mgmt_mask = IPAddr.new(management_net.instance_variable_get('@mask_addr'),
                           Socket::AF_INET).to_s
    storage_mask = IPAddr.new(storage_net.instance_variable_get('@mask_addr'),
                              Socket::AF_INET).to_s
    float_mask = IPAddr.new(float_net.instance_variable_get('@mask_addr'),
                            Socket::AF_INET).to_s

    bootstrap.vm.network(:private_network,
                         ip: management_net.succ.succ.to_s,
                         netmask: mgmt_mask,
                         adapter_ip: management_net.succ.to_s,
                         type:     :static)

    bootstrap.vm.network(:private_network,
                         ip: storage_net.succ.succ.to_s,
                         netmask: storage_mask,
                         adapter_ip: storage_net.succ.to_s,
                         type:     :static)

    bootstrap.vm.network(:private_network,
                         ip: float_net.succ.succ.to_s,
                         netmask: float_mask,
                         adapter_ip: float_net.succ.to_s,
                         type:     :static)

    if File.basename(File.expand_path('.')) == 'vbox'
      bootstrap.vm.synced_folder '../', '/chef-bcpc-host'
    else
      bootstrap.vm.synced_folder './', '/chef-bcpc-host'
    end

    # set up repositories
    if $bach_local_mirror
      bootstrap.vm.provision :shell, inline: <<-EOH
        sed -i s/archive.ubuntu.com/#{$bach_local_mirror}/g /etc/apt/sources.list
        sed -i s/security.ubuntu.com/#{$bach_local_mirror}/g /etc/apt/sources.list
        sed -i s/^deb-src/\#deb-src/g /etc/apt/sources.list
      EOH
    end
  end

  config.vm.box = 'trusty64'
  config.vm.box_url = 'trusty-server-cloudimg-amd64-vagrant-disk1.box'

  memory = ENV['BOOTSTRAP_VM_MEM'] || '2048'
  cpus = ENV['BOOTSTRAP_VM_CPUs'] || '1'

  config.vm.provider :virtualbox do |vb|
    # Don't boot with headless mode
    vb.gui = false
    vb.name = bootstrap_hostname.to_s
    vb.customize ['modifyvm', :id, '--nictype2', '82543GC']
    vb.customize ['modifyvm', :id, '--memory', memory]
    vb.customize ['modifyvm', :id, '--cpus', cpus]
    vb.customize ['modifyvm', :id, '--largepages', 'on']
    vb.customize ['modifyvm', :id, '--nestedpaging', 'on']
    vb.customize ['modifyvm', :id, '--vtxvpid', 'on']
    vb.customize ['modifyvm', :id, '--hwvirtex', 'on']
    vb.customize ['modifyvm', :id, '--ioapic', 'on']
  end
end
