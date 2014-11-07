#
# Cookbook Name:: bcpc_hadoop
# Recipe:: hdp_repo
#
# Copyright 2014, Bloomberg Finance L.P.
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

case node["platform_family"]
  when "debian"
    apt_repository "hortonworks" do
      uri node['bcpc']['repos']['hortonworks']
      distribution node[:bcpc][:hadoop][:distribution][:version]
      components ["main"]
      arch "amd64"
      key node[:bcpc][:hadoop][:distribution][:key]
    end
    apt_repository "hdp-utils" do
      uri node['bcpc']['repos']['hdp_utils']
      distribution "HDP-UTILS"
      components ["main"]
      arch "amd64"
      key node[:bcpc][:hadoop][:distribution][:key]
    end
  when "rhel"
    ""
    # do things on RHEL platforms (redhat, centos, scientific, etc)
end

