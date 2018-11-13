require 'chef-vault'

root_password = get_config('root-password')
root_password = secure_password if root_password.nil?

chef_vault_secret 'passwords' do
  data_bag 'os'
  raw_data('root-password' => root_password)
  admins [node[:fqdn], 'admin']
  search '*:*'
  action :create_if_missing
end
