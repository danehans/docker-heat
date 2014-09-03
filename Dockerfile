# Heat
#
# VERSION               0.0.1

FROM      systemd_rhel7
MAINTAINER Daneyon Hansen "daneyonhansen@gmail.com"

RUN curl --url http://173.39.232.144/repo/redhat.repo --output /etc/yum.repos.d/redhat.repo
RUN yum -y update; yum clean all
RUN yum -y install openssl ntp findutils git puppet wget

ADD start.sh /usr/local/bin/start.sh
RUN chmod 755 /usr/local/bin/start.sh

EXPOSE 8004

#CMD ["/usr/local/bin/start.sh"]
