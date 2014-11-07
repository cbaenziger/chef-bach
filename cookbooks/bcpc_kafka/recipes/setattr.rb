#
# Cookbook Name:: kafka-bcpc
# Recipe: setattr

# Override JAVA related node attributee
node.override['java']['jdk_version'] = '7'
node.override['java']['jdk']['7']['x86_64']['url'] = get_binary_server_url + "jdk-7u51-linux-x64.tar.gz"
node.override['java']['jdk']['7']['i586']['url'] = get_binary_server_url + "jdk-7u51-linux-i586.tar.gz"

# Get Kafka Zookeeper servers
zk_hosts = get_zk_nodes

# Override Kafka related node attributes
node.override[:kafka][:zookeeper][:connect] = zk_hosts.map{|x| float_host(x[:hostname])}
node.override[:kafka][:base_url] = get_binary_server_url + "kafka"
node.override[:kafka][:host_name] = float_host(node[:fqdn])
node.override[:kafka][:advertised_host_name] = float_host(node[:fqdn])
node.override[:kafka][:advertised_port] = 9092
node.override[:kafka][:jmx_port] = node[:bcpc][:hadoop][:kafka][:jmx][:port]
node.override[:kafka][:automatic_start] = true
node.override[:kafka][:automatic_restart] = true

# Override Zookeeper related node attributes
node.override[:bcpc][:hadoop][:zookeeper][:servers] = get_req_node_attributes(get_zk_nodes,HOSTNAME_NODENO_ATTR_SRCH_KEYS)
