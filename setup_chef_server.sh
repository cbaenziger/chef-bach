#!/bin/bash

#
# This script expects to be run in the chef-bcpc directory
#

set -e
set -x

# Default to Test-Laptop if environment not passed in
ENVIRONMENT="${1-Test-Laptop}"

# We may need the proxy for apt-get later
if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi

if [[ -z "$CURL" ]]; then
  echo "CURL is not defined"
  exit
fi

# Make the bootstrap a client of its own BCPC local repo
echo "deb [trusted=yes arch=amd64] file://$(pwd)/bins/ 0.5.0 main" > \
     /etc/apt/sources.list.d/bcpc.list

# Update only the BCPC local repo
if [ -f /home/vagrant/chef-bcpc/bins/apt_key.pub ]; then
  apt-key add /home/vagrant/chef-bcpc/bins/apt_key.pub || true
fi
apt-get -o Dir::Etc::SourceList=/etc/apt/sources.list.d/bcpc.list \
	-o Dir::Etc::SourceParts="-" \
	-o APT::Get::List-Cleanup="0" \
	update

if dpkg -s chef-server-core 2>/dev/null | grep -q ^Status.*installed; then
  chef-server-ctl restart
  echo 'chef-server is installed and the server has been restarted'
else
  apt-get -y install chef-server-core
  mkdir -p /etc/chef-server
  printf "nginx['enable_non_ssl'] = false\n" >> /etc/opscode/chef-server.rb
  printf "nginx['non_ssl_port'] = 4000\n" >> /etc/opscode/chef-server.rb
  # we can take about 45 minutes to Chef the first machine when running on VMs
  # so follow tuning from CHEF-4253
  printf "opscode_erchef['s3_url_ttl'] = 3600\n" >> /etc/opscode/chef-server.rb
  export NO_PROXY=${NO_PROXY-127.0.0.1,$(hostname),$(hostname -f)}
  chef-server-ctl reconfigure

  # Create Chef Admin User
  password="$(dd if=/dev/urandom count=1 status=none | tr -dc '[]{}|\/!,.<>?@#$%^&*()_+=-A-Za-z0-9' | dd count=20 bs=1 status=none)"
  # should likely use node['bcpc']['admin_email'] for e-mail
  chef-server-ctl user-create admin Admin User nobody@example.com "$password" --filename /etc/chef-server/admin.pem
  chown root:adm /etc/chef-server/admin.pem
  chmod 550 /etc/chef-server/admin.pem
  chef-server-ctl grant-server-admin-permissions admin
  chef-server-ctl org-create ${ENVIRONMENT,,} "Chef-BACH Test-Laptop Environment" --association_user admin > /etc/chef-server/${ENVIRONMENT,,}-validator.pem
  chef-server-ctl org-user-add ${ENVIRONMENT,,} admin

  # Create Bootstrap Node Client
  mkdir -p /etc/chef/trusted_certs
  knife ssl fetch --server-url https://$(hostname -f)/organizations/${ENVIRONMENT,,}
  knife client create $(hostname -f) --disable-editing --environment ${ENVIRONMENT,,} \
    --server-url https://$(hostname -f)/organizations/${ENVIRONMENT,,} \
    --file /etc/chef/client.pem --user admin --key /etc/chef-server/admin.pem
  chef gem install knife-acl
  knife acl add client $(hostname -f) containers data \
    create,update,delete,grant -u admin -k /etc/chef-server/admin.pem \
    --server-url https://$(hostname -f)/organizations/${ENVIRONMENT,,}
fi

# copy our ssh-key to be authorized for root
if [[ -f $HOME/.ssh/authorized_keys && ! -f /root/.ssh/authorized_keys ]]; then
  if [[ ! -d /root/.ssh ]]; then
    mkdir /root/.ssh
  fi
  cp $HOME/.ssh/authorized_keys /root/.ssh/authorized_keys
fi


