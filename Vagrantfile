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
prefix = File.basename(File.expand_path('.')) == 'vbox' ? '../' : ''
require_relative "#{prefix}lib/cluster_data"
require_relative "#{prefix}lib/hypervisor_node"

include BACH::ClusterData
include BACH::ClusterData::HypervisorNode

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
if ENV['BACH_DEBUG']
  $stderr.puts "Base directory is : #{repo_dir}"
end

chef_env = JSON.parse(File.read(chef_environment_path))

cluster_environment = chef_env['name']

bootstrap_hostname =
  chef_env['override_attributes']['bcpc']['bootstrap']['hostname']

bootstrap_domain =
  chef_env['override_attributes']['bcpc']['domain_name'] || 'bcpc.example.com'

# get proxy from Chef environment
proxy_url = chef_env["override_attributes"]["bcpc"]["bootstrap"]["proxy"]

# Management IP, Float IP, Storage IP
rack = chef_env['override_attributes']['bcpc']['networks'].keys.first
network_json = chef_env['override_attributes']['bcpc']['networks'][rack]
management_net =
  IPAddr.new(network_json['management']['cidr'] || '10.0.100.0/24')
management_net_i = management_net.to_i
hypervisor_management_ip = IPAddr.new(management_net.to_i + 2, Socket::AF_INET).to_s
float_net =
  IPAddr.new(network_json['floating']['cidr'] || '192.168.100.0/24')
float_net_i = float_net.to_i
hypervisor_float_ip = IPAddr.new(float_net.to_i + 2, Socket::AF_INET).to_s
storage_net =
  IPAddr.new(network_json['storage']['cidr'] || '172.16.100.0/24')
storage_net_i = storage_net.to_i
hypervisor_storage_ip = IPAddr.new(storage_net.to_i + 2, Socket::AF_INET).to_s

# Awaiting https://github.com/ruby/ruby/pull/1269 to properly retrieve mask
mgmt_mask = IPAddr.new(management_net.instance_variable_get('@mask_addr'),
                       Socket::AF_INET).to_s
storage_mask = IPAddr.new(storage_net.instance_variable_get('@mask_addr'),
                          Socket::AF_INET).to_s
float_mask = IPAddr.new(float_net.instance_variable_get('@mask_addr'),
                        Socket::AF_INET).to_s

# We rely on global variables to deal with Vagrantfile scoping rules.
# rubocop:disable Style/GlobalVars
bach_local_mirror = nil

# Generic VirtualBox settings for all VMs
common_vb_settings = Proc.new do |vb|
  # Don't boot with headless mode
  vb.gui = false
  vb.customize ['modifyvm', :id, '--nictype2', '82543GC']
  vb.customize ['modifyvm', :id, '--largepages', 'on']
  vb.customize ['modifyvm', :id, '--nestedpaging', 'on']
  vb.customize ['modifyvm', :id, '--vtxvpid', 'on']
  vb.customize ['modifyvm', :id, '--hwvirtex', 'on']
  vb.customize ['modifyvm', :id, '--ioapic', 'on']
end

# Generic Vagrant settings for all VMs
common_vagrant_settings = Proc.new do |config|
  config.vm.box = 'bionic64'
  config.vm.box_url = 'bionic-server-cloudimg-amd64-vagrant-disk1.box'

  # enable password based authentication
  config.vm.provision :shell,
      :inline => "sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config && systemctl restart sshd.service"

  # provide a proxy for apt
  if proxy_url
    config.vm.provision :shell,
      :inline => "echo 'Acquire::http::Proxy \"#{proxy_url}\";' >> /etc/apt/apt.conf"
  end

  # set up repositories
  if bach_local_mirror
    config.vm.provision :shell, inline: <<-EOH
      sed -i s/archive.ubuntu.com/#{bach_local_mirror}/g /etc/apt/sources.list
      sed -i s/security.ubuntu.com/#{bach_local_mirror}/g /etc/apt/sources.list
      sed -i s/^deb-src/\#deb-src/g /etc/apt/sources.list
    EOH
  end
end

Vagrant.configure('2') do |config|
  #
  # settings common to all VMs
  #
  common_vagrant_settings.call(config)

  #
  # bootstrap host settings
  #
  config.vm.define bootstrap_hostname.to_sym, primary: true do |bootstrap|
    bootstrap.vm.hostname = "#{bootstrap_hostname}.#{bootstrap_domain}"

    bootstrap.vm.network(:private_network,
                         ip:         IPAddr.new(management_net_i + 3,
                                                Socket::AF_INET).to_s,
                         netmask:    mgmt_mask,
                         adapter_ip: hypervisor_management_ip,
                         type:       :static)
    bootstrap.vm.network(:private_network,
                         ip:         IPAddr.new(storage_net_i + 3,
                                                Socket::AF_INET).to_s,
                         netmask:    storage_mask,
                         adapter_ip: hypervisor_storage_ip,
                         type:       :static)
    bootstrap.vm.network(:private_network,
                         ip:         IPAddr.new(float_net_i + 3,
                                                Socket::AF_INET).to_s,
                         netmask:    float_mask,
                         adapter_ip: hypervisor_float_ip,
                         type:       :static)

    if File.basename(File.expand_path('.')) == 'vbox'
      bootstrap.vm.synced_folder '../', '/chef-bcpc-host'
    else
      bootstrap.vm.synced_folder './', '/chef-bcpc-host'
    end

    memory = ENV['BOOTSTRAP_VM_MEM'] || '2048'
    cpus = ENV['BOOTSTRAP_VM_CPUs'] || '1'

    bootstrap.vm.provider :virtualbox do |vb|
      vb.name = bootstrap_hostname.to_s
      vb.customize ['modifyvm', :id, '--memory', memory]
      vb.customize ['modifyvm', :id, '--cpus', cpus]
      common_vb_settings.call(vb)
    end
  end

  #
  # cluster node settings
  #
  memory = ENV['CLUSTER_VM_MEM'] || '2048'
  cpus = ENV['CLUSTER_VM_CPUs'] || '1'
  drive_size = ENV['CLUSTER_VM_DRIVE_SIZE'] || 5 * 1024
  parse_cluster_txt(cluster_txt).each do |node|
    config.vm.define node[:hostname].to_sym, autostart: false do |cluster_node|
      cluster_node.vm.hostname = "#{node[:hostname]}.#{node[:dns_domain]}"
 
      network_offset = IPAddr.new(node[:ip_address]).to_i - management_net_i
      cluster_node.vm.network(:private_network,
                           ip:         IPAddr.new(management_net_i + network_offset,
                                                  Socket::AF_INET).to_s,
                           netmask:    mgmt_mask,
                           adapter_ip: hypervisor_management_ip,
                           type:       :static)
      cluster_node.vm.network(:private_network,
                           ip:         IPAddr.new(storage_net_i + network_offset,
                                                  Socket::AF_INET).to_s,
                           netmask:    storage_mask,
                           adapter_ip: hypervisor_storage_ip,
                           type:       :static)
      cluster_node.vm.network(:private_network,
                           ip:         IPAddr.new(float_net_i + network_offset,
                                                  Socket::AF_INET).to_s,
                           netmask:    float_mask,
                           adapter_ip: hypervisor_float_ip,
                           type:       :static)
      cluster_node.vm.provider :virtualbox do |vb|
        vb.linked_clone = true
        vb.name = node[:hostname]
        vb.customize ['modifyvm', :id, '--memory', memory]
        vb.customize ['modifyvm', :id, '--cpus', cpus]

        # Ensure we add disks to the controller used by Vagrant due to
        # https://www.virtualbox.org/ticket/6979
        disk_controller = "SCSI"
        # the vagrant box creates two disks, we will start on the third
        port_offset = 3
        ('a'...'c').map.with_index do |disk, i|
          disk_path = File.join(repo_dir, 'vbox', node[:hostname],
                                "#{node[:hostname]}-#{disk}.vdi")
          unless File.exist?(disk_path)
            vb.customize ['createhd', '--filename', disk_path, '--variant',
                          'Fixed', '--size', drive_size]
          end
          vb.customize ['storageattach', :id,  '--storagectl', disk_controller,
                        '--port', port_offset + i, '--device', 0, '--type',
                        'hdd', '--medium', disk_path]
        end
        common_vb_settings.call(vb)
      end
    end
  end
end
