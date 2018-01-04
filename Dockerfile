FROM centos:7
MAINTAINER Nico Hoffmann
ENV container=docker

# Install systemd -- See https://hub.docker.com/_/centos/
RUN yum -y update; yum clean all; \
(cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;

# Install Ansible and other requirements.
RUN yum makecache fast \
 && yum -y install deltarpm epel-release initscripts \
 && yum -y update \
 && yum -y install \
      ansible \
      sudo \
      which \
      zip \
      unzip \
      python-pip \
 && yum clean all

RUN ansible-galaxy install\
    srsp.oracle-java 

RUN mkdir /tmp/ansible
WORKDIR /tmp/ansible
ADD java.yml /tmp/ansible/java.yml
## Downloading Java
#RUN wget --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/$JAVA_VERSION-$BUILD_VERSION/jdk-$JAVA_VERSION-linux-x64.rpm" -O /tmp/jdk-8-linux-x64.rpm
#ADD java/jdk-8u151-linux-x64.rpm /tmp/ansible/files/jdk-8u151-linux-x64.rpm
RUN ansible-playbook -i localhost, java.yml

# Disable requiretty.
RUN sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/'  /etc/sudoers

# Install Ansible inventory file.
RUN echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts

VOLUME ["/sys/fs/cgroup"]
CMD ["/usr/sbin/init"]

# Configuration variables.
ENV CONFLUENCE_HOME     /var/atlassian/confluence
ENV CONFLUENCE_INSTALL  /opt/atlassian/confluence
ENV CONFLUENCE_VERSION  6.5.1


# Install Atlassian JIRA and helper tools and setup initial home
# directory structure.
RUN set -x \
    && mkdir -p                "${CONFLUENCE_HOME}" \
    && mkdir -p                "${CONFLUENCE_HOME}/caches/indexes" \
    && chmod -R 700            "${CONFLUENCE_HOME}" \
    && chown -R daemon:daemon  "${CONFLUENCE_HOME}" \
    && mkdir -p                "${CONFLUENCE_INSTALL}/conf/Catalina" \
    && chown -R daemon:daemon  "${CONFLUENCE_INSTALL}"  
RUN curl -Ls                   "http://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${CONFLUENCE_VERSION}.tar.gz" | tar -xz --directory "${CONFLUENCE_INSTALL}" --strip-components=1 --no-same-owner \
    && chmod -R 700            "${CONFLUENCE_INSTALL}/conf" \
    && chmod -R 700            "${CONFLUENCE_INSTALL}/logs" \
    && chmod -R 700            "${CONFLUENCE_INSTALL}/temp" \
    && chmod -R 700            "${CONFLUENCE_INSTALL}/work" \
    && chown -R daemon:daemon  "${CONFLUENCE_INSTALL}/conf" \
    && chown -R daemon:daemon  "${CONFLUENCE_INSTALL}/logs" \
    && chown -R daemon:daemon  "${CONFLUENCE_INSTALL}/temp" \
    && chown -R daemon:daemon  "${CONFLUENCE_INSTALL}/work" \
    && echo -e                 "\nconfluence.home=$CONFLUENCE_HOME" >> "${CONFLUENCE_INSTALL}/atlassian-confluence/WEB-INF/classes/confluence-application.properties" \
    && touch -d "@0"           "${CONFLUENCE_INSTALL}/conf/server.xml"

#ADD server.xml "${CONFLUENCE_INSTALL}/conf/server.xml"
#ADD setenv.sh "${CONFLUENCE_INSTALL}/bin/setenv.sh"

RUN set -x \
    && chown -R daemon:daemon  "${CONFLUENCE_INSTALL}/bin" "${CONFLUENCE_INSTALL}/conf" 

# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
USER daemon:daemon

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["/var/atlassian/confluence", "/opt/atlassian/confluence/logs"]

# Expose default HTTP connector port.
EXPOSE 8080

# Set the default working directory as the installation directory.
WORKDIR /var/atlassian/confluence

# Run Atlassian CONFLUENCE as a foreground process by default.
CMD ["/opt/atlassian/confluence/bin/catalina.sh", "run"]
