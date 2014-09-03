docker-heat
===========

0.0.1 - 2014.1.2-1 - Icehouse

Overview
--------

Run OpenStack Heat in a Docker container.


Caveats
-------

The systemd_rhel7 base image used by the Heat container is a private image.
Use the [Get Started with Docker Containers in RHEL 7](https://access.redhat.com/articles/881893)
to create your base rhel7 image. Then enable systemd within the rhel7 base image. 
Use [Running SystemD within a Docker Container](http://rhatdan.wordpress.com/2014/04/30/running-systemd-within-a-docker-container/) to enable SystemD.

The container does not setup Keystone endpoints for Heat. This is a task the Keystone service is responsible for.

Although the container does initialize the database used by Heat, it does not create the database, permissions, etc.. These are responsibilities of the database service.

The container does not include any OpenStack clients. After the Heat container is running, issues Heat commands from a host running the python-heatclient.

Installation
------------

This guide assumes you have Docker installed on your host system. Use the [Get Started with Docker Containers in RHEL 7](https://access.redhat.com/articles/881893] to install Docker on RHEL 7) to setup your Docker on your RHEL 7 host if needed.

### From Github

Clone the Github repo and change to the project directory:
```
yum install -y git
git clone https://github.com/danehans/docker-heat.git
cd docker-heat
```
Edit the heat.conf file according to your deployment needs then build the Heat image. Refer to the OpenStack [Icehouse installation guide](http://docs.openstack.org/icehouse/install-guide/install/yum/content/heat-install.html) for details. Next, build your Docker Heat image.
```
docker build heat .
```
**Note:** You can safely ignore the following warning messages during the build process:

*No handlers could be found for logger "heat.common.config"
/usr/lib64/python2.7/site-packages/sqlalchemy/engine/default.py:324: Warning: Specified key was too long; max key length is 767 bytes
  cursor.execute(statement, parameters)*

The image should now appear in your image list:
```
# docker images
REPOSITORY                TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
heat                      latest              d75185a8e696        3 minutes ago       555 MB
```
Run the Heat container. The example below uses the -h flag to configure the hostame as heat within the container, exposes TCP port 8004 on the Docker host, names the container heat, uses -d to run the container as a daemon. 
```
docker run --privileged -d -h heat -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
-p 8004:8004 --name="heat" heat
```
**Note:** SystemD requires CAP_SYS_ADMIN capability and access to the cgroup file system within a container. Therefore, --privileged and -v /sys/fs/cgroup:/sys/fs/cgroup:ro are required flags.

Verification
------------

Verify your Heat container is running:
```
# docker ps
CONTAINER ID  IMAGE         COMMAND          CREATED             STATUS              PORTS                    NAMES
96173898fa16  heat:latest   /usr/sbin/init   About an hour ago   Up 51 minutes       0.0.0.0:8004->8004/tcp   heat
```
Access the shell from your container:
```
# docker inspect --format='{{.State.Pid}}' heat
```
The command above will provide a process ID of the Heat container that is used in the following command:
```
# nsenter -m -u -n -i -p -t <PROCESS_ID> /bin/bash
bash-4.2#
```
From here you can perform limited functions such as viewing the installed RPMs, the heat.conf file, etc..

Deploy a Heat Stack
-------------------

Clone the heat-template repo from Github:
```
git clone https://github.com/openstack/heat-templates.git
```
Create a Heat stack. Replace <NET_ID> and <SUBNET_ID> with the Neutron network and subnet IDs used to spawn tenant instances. Replace <ADMIN_KEY> with the name of your Nova keypair. Replace <IMAGE_NAME> with the name of the Glance image used to spawn Nova instances.
```
heat stack-create test-stack \
--template-file=heat-templates/hot/servers_in_existing_neutron_network_no_floating_ips.yaml \
--parameters="key_name=<ADMIN_KEY>;image=<IMAGE_NAME>;flavor=m1.tiny;\
net_id=<NET_ID>;subnet_id=<SUBNET_ID>"
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
iptables -L
```
To change iptables rules:
```
vi /etc/sysconfig/iptables
systemctl restart iptables.service
```
