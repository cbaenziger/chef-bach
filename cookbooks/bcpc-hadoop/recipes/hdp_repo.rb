case node["platform_family"]
  when "debian"
    apt_repository "hortonworks-#{node[:bcpc][:hadoop][:distribution][:version]}" do
      uri node['bcpc']['repos']['apt']['hortonworks']
      distribution node[:bcpc][:hadoop][:distribution][:version]
      components ["main"]
      arch "amd64"
      key node[:bcpc][:hadoop][:distribution][:key]
    end
    apt_repository "hdp-utils-#{node['bcpc']['repos']['hdp_utils']['version']}" do
      uri node['bcpc']['repos']['apt']['hdp_utils']
      distribution "HDP-UTILS"
      components ["main"]
      arch "amd64"
      key node[:bcpc][:hadoop][:distribution][:key]
    end
  when "rhel"
    yum_repository "HDP-#{node["bcpc"]["hadoop"]["distribution"]["release"]}" do
      description "HDP Version - #{node["bcpc"]["hadoop"]["distribution"]["release"]}"
      baseurl node['bcpc']['repos']['yum']['hortonworks']['url']
      gpgkey node['bcpc']['repos']['yum']['hortonworks']['key_url']
      action :create
    end
    yum_repository "HDP-UTILS-#{node['bcpc']['repos']['hdp_utils']['version']}" do
      description "HDP Utils Version - #{node['bcpc']['repos']['hdp_utils']['version']}"
      baseurl node['bcpc']['repos']['yum']['hortonworks']['url']
      gpgkey node['bcpc']['repos']['yum']['hortonworks']['key_url']
      action :create
    end
end

