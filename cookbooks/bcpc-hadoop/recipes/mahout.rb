package "mahout"
bash "hdp-select mahout-client" do
  code "hdp-select set mahout-client #{node[:bcpc][:hadoop][:distribution][:release]}"
  subscribes :run, "package[mahout-client]", :immediate
  action :nothing
end
