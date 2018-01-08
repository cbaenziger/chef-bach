# vim: tabstop=2:shiftwidth=2:softtabstop=2

::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)

[ hwx_pkg_str("slider", node[:bcpc][:hadoop][:distribution][:release]) ].each do |pkg|
  package pkg do
    action :upgrade
  end
end

hdp_select('slider-client', node[:bcpc][:hadoop][:distribution][:active_release])

node.default['bcpc']['hadoop']['slider']['env'] = {}
node.default['bcpc']['hadoop']['slider']['env'].tap do |slider_env|
  slider_env['JAVA_HOME'] = node[:bcpc][:hadoop][:java]
  slider_env['HADOOP_CONF_DIR'] = '/etc/hadoop/conf'
end

template '/etc/slider/conf/slider-env.sh' do
  source 'generic_env.sh.erb'
  mode 0o0555
  variables(options: node['bcpc']['hadoop']['slider']['env'])
end
