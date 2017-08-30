#
# Cookbook Name:: bcpc
# Recipe:: haproxy
#
# Copyright 2013, Bloomberg Finance L.P.
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

include_recipe "bcpc::default"

make_config('haproxy-stats-user', "haproxy")

# backward compatibility
haproxy_stats_password = get_config("haproxy-stats-password")
if haproxy_stats_password.nil?
  haproxy_stats_password = secure_password
end

haproxy_admins = (get_head_node_names + [get_bootstrap]).join(',')

chef_vault_secret "haproxy-stats" do
  data_bag 'os'
  raw_data({ 'password' => haproxy_stats_password })
  admins haproxy_admins
  search '*:*'
  action :nothing
end.run_action(:create_if_missing)

haproxy_install 'package'

haproxy_config_global '' do
  chroot '/var/lib/haproxy'
  daemon true
  maxconn 8000
  log '/dev/log local0'
  pidfile '/var/run/haproxy.pid'
  stats socket: '/var/lib/haproxy/stats level admin'
  tuning 'bufsize' => '262144'
end

haproxy_config_defaults 'defaults' do
  mode 'http'
  extra_options 'option abortonclose': '',
                'option tcplog': '',
                'option dontlognull': '',
                'option nolinger': '',
                'option redispatch': ''
  haproxy_retries 3
  timeout  'http-request': '10s',
           queue: '1m',
           connect: '5s',
           check: '10s',
           client: '30m',
           server: '30m'
end

haproxy_frontend "stats" do
  bind "#{node[:bcpc][:management][:ip]}:1936"
  mode 'http'
  stats enable: '',
        uri: '/',
        'hide-version': '',
        realm: 'Haproxy\ Statistics',
        auth: "#{get_config!('haproxy-stats-user')}:" +
              get_config!('password','haproxy-stats','os')
  default_backend 'stats-vip-backend'
end

haproxy_frontend "stats-vip" do
  bind "#{node[:bcpc][:management][:vip]}:1936"
  mode 'http'
  default_backend 'stats-vip-backend'
end

haproxy_backend 'stats-vip-backend' do
  mode 'http'
  server ["myself #{node[:bcpc][:management][:ip]}:1936"]
end

ruby_block 'print haproxy info' do
  block do
    puts resources(template: '/etc/haproxy/haproxy.cfg').variables
  end
  subscribes :run, 'template[/etc/haproxy/haproxy.cfg]', :immediate
  subscribes :run, 'poise_service[haproxy]', :delayed
end
