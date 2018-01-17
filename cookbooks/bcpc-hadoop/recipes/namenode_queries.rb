node.default['bcpc']['hadoop']['graphite']['service_queries']['namenode'] = {
  'namenode.HeapMemoryUsage_committed' => {
     'query' => "minSeries(jmx.namenode.#{node.chef_environment}.*.memory.HeapMemoryUsage_committed)",
     'trigger_val' => "max(#{node["bcpc"]["hadoop"]["zabbix"]["triggers_sensitivity"]}m)",
     'trigger_cond' => "=0",
     'trigger_name' => "NameNodeAvailability",
     'enable' => true,
     'trigger_dep' => [],
     'trigger_desc' => "Namenode service seems to be down",
     'severity' => 5,
     'route_to' => "admin"
  }
}
