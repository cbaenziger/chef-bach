#
# Cookbook Name:: copylogs
# Recipe:: build_flume
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
#
# Acquires and packages Flume
#
# Pre-requisites: git, java and maven are installed

require 'fileutils'

build_dir = ::File.join(Chef::Config.file_cache_path, 'flume_build')
flume_version = node['copylogs']['flume']['version'])
flume_archive = ::File.join(build_dir, "apache-flume-#{flume_version}.tar.gz") do

directory build_dir do
  action :create
  not_if { ::File.exist?(target_filepath) }
end

gem_package 'fpm' do
  gem_binary '/usr/bin/gem'
  action :install
end

remote_file flume_archive do
  source node['copylogs']['flume']['distribution']['url']
  checksum node['copylogs']['flume']['distribution']['checksum']
  not_if { ::File.exist?(target_filepath) }
  notifies :run, 'bash[expand flume]', :immediately
  notifies :run, 'bash[build flume package]', :immediately
end

bash 'expand flume' do
  code "tar -xzf #{flume_archive}"
  cwd build_dir
  action :nothing
end

bash 'build flume package' do
  cwd build_dir
  user 'root'
  group 'root'
  code %Q{
    fpm -s dir -t deb --prefix /usr/local \
        -n #{node['copylogs']['flume']['package']['short_name']} \
        -v #{flume_version} \
        * && \
    mv #{node['copylogs']['flume']['package']['short_name']} #{target_filepath}
  }
  umask 0002
  action :nothing
end
