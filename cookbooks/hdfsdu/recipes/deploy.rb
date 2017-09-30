#
# Cookbook Name:: hdfsdu
# Recipe:: deploy
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
# Downloads hdfsdu zip, configures and starts hdfsdu webservice
# Will periodically compare hdfsdu data in HDFS and pull it down if it has
# a newer timestamp than stored in the Chef node attribute

require 'mixlib/shellout'
Chef::Resource.send(:extend, Hdfsdu::Helper)

src_filename = "hdfsdu-service-#{node[:hdfsdu][:version]}-bin.zip"
owner = node[:hdfsdu][:owner]
group = node[:hdfsdu][:group]
service_user = node[:hdfsdu][:user]
service_group = node[:hdfsdu][:user_group]
hdfs_user = node[:hdfsdu][:hdfs_user]
file_mode = node[:hdfsdu][:file_mode]
install_dir = node[:hdfsdu][:install_dir]
log_dir = node[:hdfsdu][:log_dir]
data_dir = node[:hdfsdu][:data_dir]
hdfsdu_data = "#{data_dir}/hdfsdu.data"
service_dir = node[:hdfsdu][:service_dir]
hdfs_path = node[:hdfsdu][:hdfs_path]
hdfs_hdfsdu_data = "#{hdfs_path}/data/hdfsdu.data"
hdfsdu_user_dir = "/user/#{hdfs_user}"
hdfsdu_user_group = node[:hdfsdu][:hdfs_user_group]

ark 'hdfsdu' do
  url "#{node[:hdfsdu][:service_download_url]}/#{src_filename}"
  path install_dir
  owner owner
  action :cherry_pick
  creates "lib/hdfsdu-service-#{node[:hdfsdu][:version]}.jar"
end

directory log_dir do
  recursive true
  owner service_user
  group service_group
  action :create
end

directory data_dir do
  recursive true
  owner service_user
  group service_group
  mode '0777'
  action :create
end

file "#{log_dir}/application.log" do
  owner service_user
  group service_group
  action :create_if_missing
end

ruby_block 'set_hdfsdu_permissions' do
  block do
    FileUtils.chmod_R 0755, Dir["#{install_dir}/hdfsdu/lib"]
  end
  action :nothing
  subscribes :run, 'ark[hdfsdu]', :immediately
end

template 'hdfsdu_service' do
  path "#{service_dir}/hdfsdu.conf"
  source 'hdfsdu.upstart.conf.erb'
  owner owner
  group group
  mode file_mode
end

bash 'create_hdfsdu_hdfs_dir' do
  code "hdfs dfs -mkdir -p #{hdfsdu_user_dir}; \\" \
       "hdfs dfs -chown #{hdfs_user}:#{hdfsdu_user_group} #{hdfsdu_user_dir}"
  user 'hdfs'
  not_if "hdfs dfs -test -d #{hdfsdu_user_dir}"
end

execute 'fetch_usage_data' do
  hdfs_time_test = "[ \"#{node[:hdfsdu][:image_timestamp]}\" != \\" \
                   "\"$(hdfs dfs -stat #{hdfs_hdfsdu_data})\" ]"
  command "hdfs dfs -get #{hdfs_hdfsdu_data} #{hdfsdu_data}.new"
  only_if "hdfs dfs -test -e #{hdfs_hdfsdu_data} && [ #{hdfs_time_test} ]",
          user: hdfs_user.to_s
  user hdfs_user
  notifies :delete, "file[#{hdfsdu_data}]", :immediately
  notifies :run, 'execute[copy_new_file]', :immediately
end

file hdfsdu_data do
  action :nothing
end

execute 'copy_new_file' do
  command "mv #{hdfsdu_data}.new #{hdfsdu_data}"
  action :nothing
  notifies :run, 'ruby_block[update_timestamp]', :immediately
end

ruby_block 'update_timestamp' do
  block do
    check_hdfs_timestamp = "sudo -u #{hdfs_user} \\" \
                           "hdfs dfs -stat #{hdfs_hdfsdu_data}"
    cmd = Mixlib::ShellOut.new(check_hdfs_timestamp, timeout: 30).run_command
    cmd.error!
    node.set[:hdfsdu][:image_timestamp] = cmd.stdout.strip
    node.save
  end
  action :nothing
end

# Start service only if the data file is >20bytes.
# This is because initial fsimage doesnt record any directories
# and hdfsdu service fails to start.
service 'hdfsdu' do
  provider Chef::Provider::Service::Upstart
  supports status: true, restart: true
  action [:enable, :start]
  only_if { ::File.exist?(hdfsdu_data) && ::File.stat(hdfsdu_data).size > 20 }
  subscribes :restart, 'ruby_block[update_timestamp]', :delayed
  notifies :run, 'ruby_block[wait_for_hdfsdu]', :delayed
end

# Confirm service did start; try until timeout and fail
ruby_block 'wait_for_hdfsdu' do
  block do
    Hdfsdu::Helper.wait_until_ready('HDFSDU',
                                    node[:hdfsdu][:service_endpoint],
                                    node[:hdfsdu][:service_timeout])
  end
  action :nothing
end
