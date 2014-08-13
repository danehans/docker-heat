# Heat
#
# VERSION               0.0.1

FROM      systemd_rhel7
MAINTAINER Daneyon Hansen "daneyonhansen@gmail.com"

RUN yum -y update; yum clean all
RUN yum -y install git puppet wget

ADD run.sh /usr/local/bin/run.sh
RUN chmod 755 /usr/local/bin/run.sh

EXPOSE 8004

CMD ["/usr/local/bin/run.sh"]
