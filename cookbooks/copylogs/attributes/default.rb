#
# Cookbook Name:: copylogs
# Attributes:: default
#
# Copyright 2018, Bloomberg Finance L.P.
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

##################################
#  copylogs specific attributes  #
##################################

default['copylogs']['flume']['version'] = '1.8.0'
default['copylogs']['flume']['distribution']['url'] = \
  'http://mirror.stjschools.org/public/apache/flume/' \
  "#{node['copylogs']['flume']['version']}/" \
  "apache-flume-#{node['copylogs']['flume']['version']}-bin.tar.gz"
default['copylogs']['flume']['distribution']['checksum'] = \
  'be1b554a5e23340ecc5e0b044215bf7828ff841f6eabe647b526d31add1ab5fa'
default['copylogs']['flume']['package']['short_name'] = 'apache_flume'
default['copylogs']['flume']['package']['name'] = \
  "#{node['copylogs']['flume']['package']['short_name']}_" \
  "#{node['copylogs']['flume']['version']}_amd64.deb"
default['copylogs']['flume']['bin_dir'] = Chef::Config.file_cache_path
default['copylogs']['flume']['package_location'] = ::File.join(
  node['copylogs']['flume']['bin_dir'],
  node['copylogs']['flume']['package']['name'])
