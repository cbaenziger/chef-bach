#
# Cookbook Name:: bach_repository
# Recipe:: ubuntu
#
include_recipe 'bach_repository::directory'
bins_dir = node['bach']['repository']['bins_directory']

remote_file "#{bins_dir}/ubuntu-14.04-hwe44-mini.iso" do
  source 'http://archive.ubuntu.com/ubuntu/dists/xenial-updates/main/' +
         'installer-amd64/current/images/hwe-netboot/mini.iso'
  mode 0444
  checksum '369bfd5fa39eaef879f1766917157ae34b38ffa1fe2607adebab516af2678b4e'
end

