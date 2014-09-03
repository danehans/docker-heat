# Heat
# VERSION               0.0.1
# Tested on RHEL7 and OSP5 (i.e. Icehouse)

FROM      systemd_rhel7
MAINTAINER Daneyon Hansen "daneyonhansen@gmail.com"

WORKDIR /root

# Uses Cisco Internal Mirror. Follow the OSP 5 Repo documentation if you are using subscription manager.
RUN curl --url http://173.39.232.144/repo/redhat.repo --output /etc/yum.repos.d/redhat.repo
RUN yum -y update; yum clean all

# Required Utilities
RUN yum -y install openssl ntp

# Heat
RUN yum -y install openstack-heat-api openstack-heat-engine
RUN mv /etc/heat/heat.conf /etc/heat.conf.save
ADD heat.conf /etc/heat/heat.conf
RUN chown root:heat /etc/heat/heat.conf
RUN systemctl enable openstack-heat-api
RUN systemctl enable openstack-heat-engine

# Initialize the Heat MySQL DB
RUN heat-manage db_sync

# Expose Heat TCP ports
EXPOSE 8004

CMD ["/usr/sbin/init"]
