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

# Configure the Keystone Host
export KEYSTONE_HOST="${KEYSTONE_HOST:-127.0.0.1}"

# Configure the Keystone Password
export KEYSTONE_PASSWORD="${KEYSTONE_PASSWORD:-changeme}"

# Configure the RabbitMQ Host
export RABBIT_HOST="${RABBIT_HOST:-127.0.0.1}"

# Configure the RabbitMQ User
export RABBIT_USER="${RABBIT_USER:-guest}"

# Configure the RabbitMQ Password
export RABBIT_PASSWORD="${RABBIT_PASSWORD:-''}"

# Configure the Database Host
export DB_HOST="${DB_HOST:-127.0.0.1}"

# Configure the Database password
export DB_PASSWORD="${DB_PASSWORD:-changeme}"

# Configure the Heat authentication encryption key
export HEAT_AUTH_KEY="${HEAT_AUTH_KEY:-changeme}"

# Set the Repo Name and Branch
export REPO_NAME="${REPO_NAME:-danehans}"
export REPO_BRANCH="${REPO_BRANCH:-combined_patches}"

# Install the Heat module. This example clones the project
# because required patches have not been merged upstream at this time.
cd ~
mkdir -p /etc/puppet/modules
if ! [ -d heat ]; then
  git clone -b $REPO_BRANCH https://github.com/$REPO_NAME/puppet-heat.git /etc/puppet/modules/heat
fi

# Install module dependencies
puppet module install puppetlabs/inifile --version '>= 1.0.0 <2.0.0'
puppet module install puppetlabs/mysql --version '>=0.9.0 <3.0.0'
puppet module install puppetlabs/rabbitmq --version '>=2.0.2 <4.0.0'
puppet module install puppetlabs/keystone --version '>=4.0.0 <5.0.0'
puppet module install puppetlabs/stdlib --version '>= 3.2.0'

# Configure the Puppet manifest
cat << EOF > /etc/puppet/heat.pp
### Begin top scope parameters ###
\$rabbit_host            = '$RABBIT_HOST'
\$rabbit_userid          = '$RABBIT_USER'
\$rabbit_password        = '$RABBIT_PASSWORD'
\$keystone_host          = '$KEYSTONE_HOST'
\$keystone_password      = '$KEYSTONE_PASSWORD'
\$db_host                = '$DB_HOST'
\$db_password            = '$DB_PASSWORD'
\$auth_encryption_key    = '$HEAT_AUTH_KEY'
### End top scope parameters ###

node default {
  Exec {
    path => ['/usr/bin', '/bin', '/usr/sbin', '/sbin']
  }

  # Install DB Client
  class { 'mysql::client': }

  # Common class
  class { 'heat':
    mysql_module      => '2.2',
    rabbit_host       => \$rabbit_host,
    rabbit_userid     => \$rabbit_userid,
    rabbit_password   => \$rabbit_password,
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
EOF

# Apply the puppet manifest to the system
mkdir -p /var/log/heat
puppet apply --detailed-exitcodes -d -v /etc/puppet/heat.pp | tee /var/log/heat/puppet-heat.log

# Stop Heat services
#systemctl stop openstack-heat-api
#systemctl stop openstack-heat-engine

# Just in case stopping service fails
#pkill -u openstack-heat-api
#pkill -u openstack-heat-engine

# Start Heat Services
#/usr/bin/openstack-heat-api
#/usr/bin/openstack-heat-engine

## Check for successful Puppet run
## Check for Root user
#if [ $? -lt 4 ]; then
#    echo "Your Puppet run was successful"
#fi
