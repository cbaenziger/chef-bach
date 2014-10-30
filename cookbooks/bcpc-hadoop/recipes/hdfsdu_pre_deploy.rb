# Setup HDFSDU config

node.override[:hdfsdu][:service_download_url] = get_binary_server_url
node.override[:bcpc][:hadoop][:hdfs][:dfs][:cluster][:administrators] = \
  node[:bcpc][:hadoop][:hdfs][:dfs][:cluster][:administrators] + 'hdfsdu'
