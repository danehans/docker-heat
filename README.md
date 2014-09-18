docker-heat
===========

0.0.1 - 2014.1.2-1 - Icehouse

Overview
--------

Run OpenStack Heat in a Docker container.

Introduction
------------

This guide assumes you have Docker installed on your host system. Use the [Get Started with Docker Containers in RHEL 7](https://access.redhat.com/articles/881893] to install Docker on RHEL 7) to setup your Docker on your RHEL 7 host if needed.

Make sure your Docker host has been configured with the required [OSP 5 channels and repositories](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux_OpenStack_Platform/5/html/Installation_and_Configuration_Guide/chap-Prerequisites.html#sect-Software_Repository_Configuration)

Reference the [Getting images from outside Docker registries](https://access.redhat.com/articles/881893#images) section of the [Get Started with Docker Containers in RHEL 7](https://access.redhat.com/articles/881893) guide
to pull your base rhel7 image from Red Hat's private registry. This is required to build the rhel7-systemd base image used by the Heat container.

After following the [Get Started with Docker Containers in RHEL 7](https://access.redhat.com/articles/881893) guide, verify your Docker Registry is running:
```
# systemctl status docker-registry
docker-registry.service - Registry server for Docker
   Loaded: loaded (/usr/lib/systemd/system/docker-registry.service; enabled)
   Active: active (running) since Mon 2014-05-05 13:42:56 EDT; 601ms ago
 Main PID: 21031 (gunicorn)
   CGroup: /system.slice/docker-registry.service
           ├─21031 /usr/bin/python /usr/bin/gunicorn --access-logfile - --debug ...
            ...
```
Now that you have the rhel7 base image, follow the instructions in the [docker-rhel7-systemd project](https://github.com/danehans/docker-rhel7-systemd/blob/master/README.md) to build your rhel7-systemd image.

The container does not setup Keystone endpoints for Heat. This is a task the Keystone service is responsible for. Reference the [docker-keystone](https://github.com/danehans/docker-keystone) project or official [OpenStack documentation](http://docs.openstack.org) for details.

Although the container does initialize the database used by Heat, it does not create the database, permissions, etc.. These are responsibilities of the database service.

Installation
------------

### From Github

Set the environment variables used to automate the image building process
```
# Name of the Github repo. Change danehans to your Github repo name if you forked my project.
export REPO_NAME=danehans
# The branch from the REPO_NAME repo.
export REPO_BRANCH=master
```
Additional environment variables that should be set:
```
# IP address/FQDN of the DB Host.
export DB_HOST=127.0.0.1
# Password used to access the Heat database.
# heat is used for the DB username.
export DB_PASSWORD=changeme
# IP address/FQDN of the RabbitMQ broker.
export RABBIT_HOST=127.0.0.1
# IP address/FQDN of the Keystone host.
export KEYSTONE_HOST=127.0.0.1
```
Optional environment variables that can be set:
```
# Name used for creating the Heat Docker image.
export HEAT_IMAGE_NAME=ouruser/heat
# Hostname used by the Heat Docker container.
export HEAT_HOSTNAME=heat.example.com
# IP address/FQDN used to bind the Heat CFN API.
export HEAT_CFN_HOST=127.0.0.1
# Heat DB authentication encryption key.
export AUTH_ENCRYPTION_KEY=changeme
# TCP port number the Keystone Public API listens on.
# Note: Docker Registry listens on port 5000.
export KEYSTONE_PUBLIC_PORT=5000
# TCP port number the Keystone Admin API listens on.
export KEYSTONE_ADMIN_PORT=35357
# Name of the Keystone tenant used by OpenStack services.
export SERVICE_TENANT=services
# Password of the Keystone service tenant.
export SERVICE_PASSWORD=cisco123
# Password of the demo user. Used by the demo-openrc credential file.
export DEMO_USER_PASSWORD=cisco123
# Password of the admin user. Used by the admin-openrc credential file.
export ADMIN_USER_PASSWORD=cisco123
```
Refer to the OpenStack [Icehouse installation guide](http://docs.openstack.org/icehouse/install-guide/install/yum/content/heat-install.html) for more details on the configuration parameters.

The [heat.conf](https://github.com/danehans/docker-heat/blob/master/data/tiller/templates/heat.conf.erb) file is managed by a tool called [Tiller](https://github.com/markround/tiller/blob/master/README.md).

If you require setting additional heat.conf configuration flags, please fork this project, make your additions, test and submit a pull request to get your changes back upstream.

Run the build script.
```
# bash <(curl \-fsS https://raw.githubusercontent.com/$REPO_NAME/docker-heat/$REPO_BRANCH/data/scripts/build)
```
**Note:** You can safely ignore the following warning messages during the build process:
```
*No handlers could be found for logger "heat.common.config"
/usr/lib64/python2.7/site-packages/sqlalchemy/engine/default.py:324: Warning: Specified key was too long; max key length is 767 bytes
  cursor.execute(statement, parameters)*
```
The image should now appear in your image list:
```
# docker images
REPOSITORY                TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
HEAT_IMAGE_NAME           latest              d75185a8e696        3 minutes ago       555 MB
```
After the Heat Docker image has been created, run a Heat container based from the newly created image. You can use the run script or run the container manually.

Option 1- Use the run script:
```
export HEAT_IMAGE_NAME=ouruser/heat
export HEAT_CONTAINER_NAME=heat
export HEAT_HOSTNAME=heat.example.com
export DNS_SEARCH=example.com
# . /$HOME/docker-heat/data/scripts/run
```
Option 2- Manually:
The example below uses the -h flag to configure the hostame as heat within the container, exposes TCP ports 8000 and 8004 on the Docker host, names the container heat, uses -d to run the container as a daemon.
```
# docker run --privileged -d -h $HEAT_HOSTNAME --dns-search $DNS_SEARCH \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro -p 8000:8000 -p 8004:8004 \
--name="$HEAT_CONTAINER_NAME" $HEAT_IMAGE_NAME
```
Example:
```
# docker run --privileged -d -h heat.example.com --dns-search example.com \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro -p 8000:8000 -p 8004:8004 \
--name="heat" ouruser/heat
```
**Note:** SystemD requires CAP_SYS_ADMIN capability and access to the cgroup file system within a container. Therefore, --privileged and -v /sys/fs/cgroup:/sys/fs/cgroup:ro are required flags.

Verification
------------

Verify your Heat container is running:
```
# docker ps
CONTAINER ID  IMAGE                 COMMAND          CREATED             STATUS              PORTS                                          NAMES
96173898fa16  ouruser/heat:latest   /usr/sbin/init   About an hour ago   Up 51 minutes       0.0.0.0:8000->8000/tcp 0.0.0.0:8004->8004/tcp  heat
```
If you started the container manually, you can access the shell from your container:
```
# docker inspect --format='{{.State.Pid}}' heat
```
The command above will provide a process ID of the Heat container that is used in the following command:
```
# nsenter -m -u -n -i -p -t $PROCESS_ID /bin/bash
bash-4.2#
```
From here you can perform limited functions such as viewing installed RPMs, the heat.conf file, etc..

Deploy a Heat Stack
-------------------

Clone the heat-template repo from Github:
```
# yum install -y git
# git clone https://github.com/openstack/heat-templates.git
```
Source your Keystone credential file:
```
# For the admin user
source /root/admin-openrc.sh
# For the demo user
source /root/demo-openrc.sh
```
Create a Heat stack. Replace $NET_ID and $SUBNET_ID with the Neutron network and subnet IDs used to spawn tenant instances. Replace $ADMIN_KEY with the name of your Nova keypair. Replace $IMAGE_NAME with the name of the Glance image used to spawn Nova instances.

**Note:** The example template used below requires an existing Neutron network/subnet, Glance image and Nova keypair. Create these if they do not exist in your deployment. Use the official [Openstack documenttion](http://www.docs.openstack.org) for further assistance.

```
# heat stack-create test-stack \
--template-file=heat-templates/hot/servers_in_existing_neutron_network_no_floating_ips.yaml \
--parameters="key_name=$ADMIN_KEY;image=$IMAGE_NAME;flavor=m1.tiny;\
net_id=$NET_ID;subnet_id=$SUBNET_ID"
```
Verify the stack has been successfully deployed.
```
# heat stack-list
+--------------------------------------+------------+-----------------+----------------------+
| id                                   | stack_name | stack_status    | creation_time        |
+--------------------------------------+------------+-----------------+----------------------+
| 249b863c-3a1e-4c97-ad30-9716adb3da25 | test-stack | CREATE_COMPLETE | 2014-09-05T08:37:49Z |
+--------------------------------------+------------+-----------------+----------------------+
```
If you have problems creating the Heat stack, use the troubleshooting section below for help. You can also use the *heat resource-list <STACK_NAME>* command to see the step at which Heat fails. You can add the --debug to your *heat stack-create* command and tail the appropriate system logs for futher analysis.

Troubleshooting
---------------

Can you connect to the OpenStack API endpints from your Docker host and container? Verify connectivity with tools such as ping and curl.

IPtables may be blocking you. Check IPtables rules on the host(s) running the other OpenStack services:
```
# iptables -L
```
To change iptables rules:
```
# vi /etc/sysconfig/iptables
# systemctl restart iptables.service
```
