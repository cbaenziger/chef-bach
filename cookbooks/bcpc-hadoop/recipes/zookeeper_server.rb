include_recipe 'bcpc-hadoop::zookeeper_config'
node.override['bcpc']['jolokia']['jvm_args'] = ''
include_recipe 'bcpc-hadoop::zookeeper_impl'

# Set Zookeeper related zabbix triggers
triggers_sensitivity = "#{node["bcpc"]["hadoop"]["zabbix"]["triggers_sensitivity"]}m"
node.set['bcpc']['hadoop']['graphite']['service_queries']['zookeeper'] = {
  'zookeeper.QuorumSize' => {
     'query' => "minSeries(jmx.zookeeper.*.zookeeper.QuorumSize)",
     'trigger_val' => "max(#{triggers_sensitivity})",
     'trigger_cond' => "<#{node[:bcpc][:hadoop][:zookeeper][:servers].length}",
     'trigger_name' => "ZookeeperQuorumAvailability",
     'enable' => true,
     'trigger_desc' => "A zookeeper node seems to be down",
     'severity' => 5,
     'route_to' => "admin"
  }
}
