name             'cache'
maintainer       'Chef Example'
maintainer_email 'admin@example.com'
license          'Apache-2.0'
description      'Configures caching services (memcached and redis)'
version          '1.0.0'
chef_version     '>= 16.0'

supports 'ubuntu', '>= 18.04'
supports 'centos', '>= 7.0'

depends 'memcached', '~> 6.0'
depends 'redisio'

