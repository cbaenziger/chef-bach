mapred_site_values = node[:bcpc][:hadoop][:mapreduce][:site_xml]

mapred_site_generated_values =
{
   
}

hs_hosts = node[:bcpc][:hadoop][:hs_hosts]
if not hs_hosts.empty?
  hs_properties =
    {
     'mapreduce.jobhistory.address' =>
       "#{float_host(hs_hosts.map{|i| i[:hostname] }.sort.first)}:10020",
     
     'mapreduce.jobhistory.webapp.address' =>
       "#{float_host(hs_hosts.map{|i| i[:hostname] }.sort.first)}:19888",
    }
  mapred_site_generated_values.merge!(hs_properties)
end

if node[:bcpc][:hadoop][:kerberos][:enable]
   kerberos_data = node[:bcpc][:hadoop][:kerberos][:data]

  if kerberos_data[:historyserver][:princhost] == '_HOST'
    kerberos_host = if node.run_list.expand(node.chef_environment).recipes
                      .include?('bcpc-hadoop::historyserver')
                      float_host(node[:fqdn])
                    else
                      '_HOST'
                    end
  else
    kerberos_host = kerberos_data[:historyserver][:princhost]
  end

  jobhistory_principal =
    kerberos_data[:historyserver][:principal] + '/' + kerberos_host + '@' +
    node[:bcpc][:hadoop][:kerberos][:realm]

  kerberos_properties =
    {
     'mapreduce.jobhistory.keytab' =>
       node[:bcpc][:hadoop][:kerberos][:keytab][:dir] + '/' +
       kerberos_data[:historyserver][:keytab],
     
     'mapreduce.jobhistory.principal' =>
       jobhistory_principal,
    }
  mapred_site_generated_values.merge!(kerberos_properties)
end

min_allocation =
    node['bcpc']['hadoop']['yarn']['scheduler']['minimum-allocation-mb']

memory_config_values =
{
 'mapreduce.map.memory.mb' => min_allocation.round,

 'mapreduce.map.java.opts' =>
    "-Xmx" + (0.8 * min_allocation).round.to_s + "m",

  'mapreduce.reduce.memory.mb' =>
    2 * min_allocation.round,

  'mapreduce.reduce.java.opts' =>
    "-Xmx" + (0.8 * 2 * min_allocation).round.to_s + "m",

  'yarn.app.mapreduce.am.resource.mb' =>
    2 * min_allocation.round,

  'yarn.app.mapreduce.am.command-opts' =>
    "-Xmx" + (0.8 * 2 * min_allocation).round.to_s + "m",
}

mapred_site_generated_values.merge!(memory_config_values)

complete_mapred_site_hash =
  mapred_site_generated_values.merge(mapred_site_values)

template "/etc/hadoop/conf/mapred-site.xml" do
  source "generic_site.xml.erb"
  mode 0644
  variables(:options => complete_mapred_site_hash)
end
