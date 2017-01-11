name             'bach_wrapper'
maintainer       'Bloomberg LP'
maintainer_email 'compute@bloomberg.net'
license          'All rights reserved'
description      'Top-level chef-bach wrapper'
long_description 'Top-level chef-bach wrapper'
version          '0.1.0'

depends 'bach_common', '= 0.1.0'
depends 'bach_krb5', '= 0.1.0'
depends 'bach_repository', '= 0.1.0'
depends 'bach_spark', '= 0.1.0'
depends 'bcpc', '= 0.1.0'
depends 'bcpc-hadoop', '= 0.1.0'
depends 'bcpc_jmxtrans', '= 0.1.0'
depends 'hannibal', '= 0.1.0'
depends 'java','>= 1.41.0'
depends 'bcpc_kafka', '= 0.1.0'
depends 'locking_resource', '= 0.1.0'

#
# Transitive dependencies specified to retain Chef 11.x compatibility.
# We should remove these as soon as a Chef 12.x migration is complete.
#
depends 'apt', '= 2.4.0'
depends 'build-essential', '= 3.2.0'
depends 'chef-client', '= 4.2.4'
depends 'chef-vault', '= 1.3.3'
depends 'cron', '~> 3.0.0'
depends 'database'
depends 'homebrew', '~> 2.1.2'
depends 'krb5', '= 2.0.0'
depends 'line'
depends 'logrotate', '~> 1.9.2'
depends 'maven', '= 2.1.1'
depends 'nscd', '~> 1.0.1'
depends 'ntp', '= 1.10.1'
depends 'ohai', '= 3.0.1'
depends 'openssl', '= 5.0.1'
depends 'poise'
depends 'postgresql', '= 5.2.0'
depends 'sysctl', '= 0.7.5'
depends 'windows', '= 1.36.6'
depends 'yum', '= 3.13.0'
depends 'yum-epel', '= 0.7.1'
depends 'chef_handler', '= 2.1.0'
