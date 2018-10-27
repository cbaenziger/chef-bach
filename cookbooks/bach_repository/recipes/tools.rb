#
# Cookbook Name:: bach_repository
# Recipe:: tools
#
require 'rubygems'
include_recipe 'ubuntu'
include_recipe 'apt'
include_recipe 'build-essential'

#
# This long list of dev/packaging tools originally came from build_bins.sh.
#
python_pkg = \
  Gem::Version.new(node['lsb']['release']) >= Gem::Version.new('16.04') ?
  'dh-python' : 'python-support'
[
  'apt-utils',
  'autoconf',
  'autogen',
  'cdbs',
  'dpkg-dev',
  'gcc',
  'git',
  'haveged',
  'libldap2-dev',
  'libmysqlclient-dev',
  'libtool',
  'make',
  'patch',
  'pkg-config',
  'pbuilder',
  'python-all-dev',
  'python-configobj',
  'python-mock',
  'python-pip',
  python_pkg,
  'python-setuptools',
  'python-stdeb',
  'rake',
  'rsync',
  'ruby',
  'ruby-dev',
  'unzip',
].each do |pkg|
  package pkg do
    action :install
    timeout 3600 if respond_to?(:timeout)
  end
end
