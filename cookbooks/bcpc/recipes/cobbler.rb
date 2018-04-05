#
# Cookbook Name:: bcpc
# Recipe:: cobbler
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

require 'digest/sha2'
require 'chef-vault'

make_config('cobbler-web-user', 'cobbler')

create_databag('os')

# TODO: Don't generate passwords at compile time.
web_password = get_config('cobbler-web-password')
web_password = secure_password if web_password.nil?

root_password = get_config('cobbler-root-password')
root_password = secure_password if root_password.nil?

root_password_salted = root_password.crypt('$6$' + rand(36**8).to_s(36))

chef_vault_secret 'cobbler' do
  data_bag 'os'
  raw_data('web-password' => web_password,
           'root-password' => root_password,
           'root-password-salted' => root_password_salted)
  admins [node[:fqdn], 'admin']
  search '*:*'
  action :create_if_missing
end

# The cobblerd cookbook relies on this attribute.
node.force_default[:cobblerd][:web_password] = web_password

[
  'python',
  'apache2',
  'libapache2-mod-wsgi',
  'python-support',
  'python-yaml',
  'python-netaddr',
  'python-cheetah',
  'debmirror',
  'syslinux',
  'python-simplejson',
  'python-urlgrabber',
  'python-django',
  'tftp-hpa',
  'tftpd-hpa',
  'xinetd'
].each do |package_name|
  package package_name do
    action :upgrade
  end
end

#
# Cobbler 2.6 expects to drop off a tftp configuration in
# /etc/xinetd.d, so we stop the independent tftp service ASAP.
#
service 'tftpd-hpa' do
  action [:stop, :disable]
end

link '/tftpboot' do
  to '/var/lib/tftpboot'
end

service 'xinetd' do
  action [:enable, :start]
end

#
# Modern revisions of cobbler may not sync a tftp configuration until
# a tftp-requiring node is enrolled.
#
# To make sure tftp is enabled immediately, we pre-seed a
# configuration just in case.
#
file '/etc/xinetd.d/tftp' do
  action :create_if_missing
  mode 0444
  user 'root'
  group 'root'
  content <<-EOM.gsub(/^ {4}/,'')
    service tftp
    {
        disable                 = no
        socket_type             = dgram
        protocol                = udp
        wait                    = yes
        user                    = root
        server                  = /usr/sbin/in.tftpd
        server_args             = -B 1380 -v -s /var/lib/tftpboot
        per_source              = 11
        cps                     = 100 2
        flags                   = IPv4
    }
  EOM
  notifies :restart, 'service[xinetd]', :immediately
end

[
  'proxy',
  'proxy_http'
].each do |mod_name|
  execute "a2enmod #{mod_name}" do
    not_if {
      File.exist?("/etc/apache2/mods-enabled/#{mod_name}.load")
    }
    #
    # We need to restart apache2 before any cobbler commands are run.
    # Restarting it multiple times is pretty harmless.
    #
    notifies :restart, 'service[apache2]', :immediately
  end
end

package 'isc-dhcp-server'

include_recipe 'cobblerd::cobbler_source_install'
include_recipe 'cobblerd::default'

template '/etc/apache2/conf.d/cobbler.conf' do
  source 'cobbler/apache.conf.erb'
  mode 00644
end

['cobbler.conf', 'cobbler_web.conf'].each do |conf_file|
  link "/etc/apache2/conf-enabled/#{conf_file}" do
    to "/etc/apache2/conf.d/#{conf_file}"
    #
    # We need to restart apache2 before any cobbler commands are run.
    # Restarting it multiple times is pretty harmless.
    #
    notifies :restart, 'service[apache2]', :immediately
  end
end

template '/etc/cobbler/settings' do
  source 'cobbler/settings.erb'
  mode 0644
  notifies :restart, "service[#{node['cobbler']['service']['name']}]", :immediately
end

template '/etc/cobbler/dhcp.template' do
  source 'cobbler/dhcp.template.erb'
  mode 0644
  variables(subnets: node[:bcpc][:networks], bootstrap_vip_ip: node['bcpc']['bootstrap']['vip'])
  notifies :run, 'bash[cobbler-sync]', :delayed
end

template '/var/lib/cobbler/scripts/select_bach_root_disk' do
  source 'cobbler/select_bach_root_disk.erb'
  mode 0644
end

cookbook_file '/var/lib/cobbler/loaders/ipxe-x86_64.efi' do
  source 'ipxe-x86_64.efi'
  mode 0644
  notifies :run, 'bash[cobbler-sync]', :delayed
end

link '/var/lib/tftpboot/ipxe-x86_64.efi' do
  to '/var/lib/cobbler/loaders/ipxe-x86_64.efi'
  link_type :hard
end

link '/var/lib/tftpboot/chain.c32' do
  to '/usr/lib/syslinux/chain.c32'
  link_type :hard
end

cobbler_image 'ubuntu-14.04-mini' do
  source "#{get_binary_server_url}/ubuntu-14.04-hwe44-mini.iso"
  os_version 'trusty'
  os_breed 'ubuntu'
  action :import
end

{
  trusty: 'ubuntu-14.04-mini-x86_64',
}.each do |version, distro_name|
  cobbler_profile "bcpc_host_#{version}" do
    kickstart "cobbler/#{version}.preseed"
    distro distro_name
    action :import
  end

  #
  # The biosdevname=0 and net.ifnames=0 kernel options are important
  # in order to force the use of old-fashioned eth0..ethN device
  # naming on Ubuntu 14.04.
  #
  # "Modern" naming schemes for network devices will break the bcpc
  # recipes for bonding.
  #
  execute 'set-ubuntu-kopts' do
    full_kopts =
      node[:bcpc][:bootstrap][:preseed][:add_kernel_opts] +
      " biosdevname=0 net.ifnames=0"

    command "cobbler distro edit " \
      "--name=#{distro_name} " \
      "--kopts='#{full_kopts}'"

    notifies :run, 'bash[cobbler-sync]', :delayed
  end
end

#
# When PXE booting an EFI host, the kernel will require an explicit
# filename for the initrd. As far as I can tell, the filename is
# relative to the kernel path.
#
# Unfortunately 'cobbler distro edit --kopts' will not allow you to
# add an initrd option to the append_line, so we have to edit the gpxe
# script directly.
#
# For Ubuntu 14.04, this means appending "initrd=initrd.gz" to the
# kernel argument list.  This template will break non-Ubuntu installs,
# because different distributions use different filenames for the
# compressed initrd.
#
file '/etc/cobbler/pxe/gpxe_system_linux.template' do
  content <<-EOM.gsub(/^ {4}/, '')
    #!gpxe
    #
    # This file was generated by Chef.
    # Local changes will be reverted.
    #
    kernel http://$server:$http_port/cobbler/images/$distro/$kernel_name
    imgargs $kernel_name initrd=initrd.gz $append_line
    initrd http://$server:$http_port/cobbler/images/$distro/$initrd_name
    boot
  EOM
  mode 0444
  notifies :run, 'bash[cobbler-sync]', :delayed
end

#
# The 'sanboot' verb is not supported on EFI, so we need to have the
# local disk template just exit the iPXE UEFI application.
#
file '/etc/cobbler/pxe/gpxe_system_local.template' do
  content <<-EOM.gsub(/^ {4}/, '')
    #!gpxe
    #
    # This file was generated by Chef.
    # Local changes will be reverted.
    #
    iseq ${platform} efi && exit

    iseq ${smbios/manufacturer} HP && exit ||
    sanboot --no-describe --drive 0x80
  EOM
  mode 0444
  notifies :run, 'bash[cobbler-sync]', :delayed
end

# The "LOCALBOOT -1" statement does not seem to work reliably on VirtualBox.
file '/etc/cobbler/pxe/pxelocal.template' do
  content <<-EOM.gsub(/^ {4}/, '')
    DEFAULT local
    PROMPT 0
    TIMEOUT 0
    TOTALTIMEOUT 0
    ONTIMEOUT local

    LABEL local
        KERNEL chain.c32
  EOM
  mode 0444
  notifies :run, 'bash[cobbler-sync]', :delayed
end

service 'isc-dhcp-server' do
  supports :status => true, :restart => true
  action [:enable,:start]
  notifies :run, 'bash[cobbler-sync]', :delayed
end
