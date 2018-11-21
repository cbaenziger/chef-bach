name             'bach_repository'
maintainer       'Bloomberg LP'
maintainer_email 'hadoop@bloomberg.net'
license          'All rights reserved'
description      'bach_repository builds a repo for use by BACH nodes'
long_description 'bach_repository builds a repo for use by BACH nodes. ' \
  'This cookbook builds binary artifacts and repositories declaratively.'
version          '0.1.0'

supports 'ubuntu'

depends 'java'
depends 'ark'
# FIXME: Remove when upgrading to chef-client 13+
# This transitive dependency of the ark cookbook.
depends 'seven_zip', '~> 3.0.0'
depends 'build-essential'
depends 'ubuntu'
