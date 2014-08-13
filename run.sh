#!/bin/bash
#
# Script to install and configure Heat in a Docker Container
#
# Tested on Openstack Icehouse RHEL7 RDO5
#
set -x
set -e

# Check for Root user
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root or with sudo"
    exit 1
fi

# Install and configure a database to support Heat
export CONFIG_DB="${CONFIG_DB:-false}"

# Install and configure Keystone Heat endpoint, service, etc..
export CONFIG_KEYSTONE="${CONFIG_KEYSTONE:-true}"

# Install and configure Heat services
export CONFIG_HEAT="${CONFIG_HEAT:-true}"

# Configure the Keystone Region
export REGION="${REGION:-RegionOne}"

# Configure the Keystone Host
export KEYSTONE_HOST="${KEYSTONE_HOST:-127.0.0.1}"

# Configure the Keystone Password
export KEYSTONE_PASSWORD="${KEYSTONE_PASSWORD:-changeme}"

# Configure the Database Host
export DB_HOST="${DB_HOST:-127.0.0.1}"

# Configure the Database password
export DB_PASSWORD="${DB_PASSWORD:-changeme}"

# Configure the Database package name
export DB_PACKAGE_NAME="${DB_PACKAGE_NAME:-mariadb-galera-server}"

# Configure the Heat authentication encryption key
export HEAT_AUTH_KEY="${HEAT_AUTH_KEY:-whatever-key-you-like}"

# Configure the Heat Keystone password
export HEAT_KEYSTONE_PASSWORD="${HEAT_KEYSTONE_PASSWORD:-changeme}"

# Configure the Heat host
export HEAT_HOST="${HEAT_HOST:-127.0.0.1}"

# Set the Repo Name and Branch
export REPO_NAME="${REPO_NAME:-danehans}"
export REPO_BRANCH="${REPO_BRANCH:-combined_patches}"

# Make Puppet Modules directory if it does not exist
mkdir -p /etc/puppet/modules

# Make log directory
mkdir -p /var/log/heat

# Install module dependencies
puppet module install puppetlabs/inifile --version '>= 1.0.0 <2.0.0'
puppet module install puppetlabs/mysql --version '>=0.9.0 <3.0.0'
puppet module install puppetlabs/rabbitmq --version '>=2.0.2 <4.0.0'
puppet module install puppetlabs/keystone --version '>=4.0.0 <5.0.0'
puppet module install puppetlabs/stdlib --version '>= 3.2.0'

# Install the Heat module. This example clones the project
# because required patches have not been merged upstream at this time.
if ! [ -d heat ]; then
  git clone -b $REPO_BRANCH https://github.com/$REPO_NAME/puppet-heat.git /etc/puppet/modules/heat
fi

# Install Heat module dependencies
puppet module install puppetlabs/inifile --version '>= 1.0.0 <2.0.0'
puppet module install puppetlabs/mysql --version '>=0.9.0 <3.0.0'
puppet module install puppetlabs/rabbitmq --version '>=2.0.2 <4.0.0'
puppet module install puppetlabs/keystone --version '>=4.0.0 <5.0.0'
puppet module install puppetlabs/stdlib --version '>= 3.2.0'

# Configure the Puppet manifest
cat << EOF > /etc/puppet/heat.pp
### Begin top scope parameters ###
\$configure_database     = $CONFIG_DB
\$configure_keystone     = $CONFIG_KEYSTONE
\$configure_heat         = $CONFIG_HEAT
\$region                 = $REGION
\$keystone_host          = $KEYSTONE_HOST
\$keystone_password      = $KEYSTONE_PASSWORD
\$db_host                = $DB_HOST
\$db_password            = $DB_PASSWORD
\$db_package_name        = $DB_PACKAGE_NAME
\$auth_encryption_key    = $HEAT_AUTH_KEY
\$heat_keystone_password = $HEAT_KEYSTONE_PASSWORD
\$heat_host              = $HEAT_HOST
### End top scope parameters ###

node default {
  Exec {
    path => ['/usr/bin', '/bin', '/usr/sbin', '/sbin']
  }

  if (\$configure_database) {
    # Install MySQL or MariaDB
    class { 'mysql::server':
      package_name => \$db_package_name,
    }
    class { 'heat::db::mysql':
      mysql_module => '2.2',
      host         => \$db_host,
      password     => \$db_password,
    }
  }

  if (\$configure_keystone) {
    # Configure Keystone for Heat support
    class { 'heat::keystone::auth':
      password         => \$heat_keystone_password,
      public_address   => \$heat_host,
      admin_address    => \$heat_host,
      internal_address => \$heat_host,
    }
  }

  if (\$configure_heat) {
    # Common class
    class { 'heat':
      mysql_module      => '2.2',
      keystone_host     => \$keystone_host,
      keystone_password => \$keystone_password,
      sql_connection    => "mysql://heat:\${db_password}@\${db_host}/heat",
    }
    # Install heat-engine
    class { 'heat::engine':
      auth_encryption_key => \$auth_encryption_key,
    }
    # Install the heat-api service
    class { 'heat::api': }
  }
}
EOF
fi

# Apply the puppet manifest to the system
puppet apply --detailed-exitcodes -d -v /etc/puppet/heat.pp | tee /var/log/heat/puppet-heat.log

# Check for successful Puppet run
# Check for Root user
if [ $? -lt 4 ]; then
    echo "Your Puppet run was successful"
fi
