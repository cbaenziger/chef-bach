#
# Cookbook Name:: bach_repository
# Recipe:: diamond
#
# This recipe leaves its source tree in place.  Since we don't know
# the intended version until we check out the repository, the source
# needs to be available every time the package is updated.
#
require 'tmpdir'

include_recipe 'bach_repository::directory'
bins_dir = node['bach']['repository']['bins_directory']
src_dir = node['bach']['repository']['src_directory']
build_dir = src_dir + '/diamond'

git build_dir do
  repository 'https://github.com/python-diamond/Diamond'
  action :sync
  not_if { File.exists?("#{bins_dir}/diamond.deb") }
end

execute 'diamond-make-builddeb' do
  command 'make builddeb'
  cwd build_dir
  not_if { File.exists?("#{bins_dir}/diamond.deb") }
end

# Copy the built deb into place in the most laborious way possible.
file "#{bins_dir}/diamond.deb" do
  content lazy {
    diamond_version = File.open("#{build_dir}/version.txt").read.chomp 
    diamond_deb_path = "#{build_dir}/build/diamond_#{diamond_version}_all.deb"
    File.open(diamond_deb_path).read
  }
  mode 0444
  not_if { File.exists?("#{bins_dir}/diamond.deb") }
end
