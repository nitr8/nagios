FROM ubuntu:16.04

ENV NAGIOS_HOME            /opt/nagios
ENV NAGIOS_USER            nagios
ENV NAGIOS_GROUP           nagios
ENV NAGIOS_CMDUSER         nagios
ENV NAGIOS_CMDGROUP        nagios
ENV NAGIOS_FQDN            nagios.example.com
ENV NAGIOSADMIN_USER       nagiosadmin
ENV NAGIOSADMIN_PASS       nagios
ENV APACHE_RUN_USER        nagios
ENV APACHE_RUN_GROUP       nagios
ENV NAGIOS_TIMEZONE        UTC
ENV DEBIAN_FRONTEND        noninteractive
ENV NG_NAGIOS_CONFIG_FILE  ${NAGIOS_HOME}/etc/nagios.cfg
ENV NG_CGI_DIR             ${NAGIOS_HOME}/sbin
ENV NG_WWW_DIR             ${NAGIOS_HOME}/share/nagiosgraph
ENV NG_CGI_URL             /cgi-bin
ENV NAGIOS_BRANCH          nagios-4.4.6
ENV NAGIOS_PLUGINS_BRANCH  release-2.2.1
ENV NRPE_BRANCH            nrpe-3.2.1
ENV LOG_DIR                /opt/logs
#new
ENV POSTFIX_RELAY          [127.0.0.1]:1025
#Environment variables to configure php
ENV PHP_UPLOAD_MAX_FILESIZE 25M
ENV PHP_POST_MAX_SIZE 25M
SHELL ["/bin/bash", "-c"]

RUN \
echo "Running debconf and OS updates and pre required packages" && \
mkdir ${LOG_DIR} && \
echo postfix postfix/main_mailer_type string "'Internet Site'" | debconf-set-selections > ${LOG_DIR}/apt.log && \
echo postfix postfix/mynetworks string "127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128" | debconf-set-selections > ${LOG_DIR}/apt.log && \
echo postfix postfix/destinations string "${NAGIOS_FQDN}, localhost.localdomain, localhost" | debconf-set-selections > ${LOG_DIR}/apt.log && \
echo postfix postfix/mailname string ${NAGIOS_FQDN} | debconf-set-selections > ${LOG_DIR}/apt.log && \
echo postfix postfix/relayhost string ${POSTFIX_RELAY} | debconf-set-selections > ${LOG_DIR}/apt.log && \
apt-get update -y -qq > ${LOG_DIR}/apt.log && \
apt-get install -y -qq apt-utils 2> >( grep -v 'debconf: delaying package configuration, since apt-utils is not installed' >&2 ) > /dev/null && \
apt-get install -y -qq --no-install-recommends \
#apt-get install -y -qq \
apache2 \
apache2-utils \
autoconf \
automake \
bc \
bsd-mailx \
build-essential \
dnsutils \
fping \
gettext \
git \
gperf \
iputils-ping \
jq \
libapache2-mod-php \
libcache-memcached-perl \
libcgi-pm-perl \
libdbd-mysql-perl \
libdbi-dev \
libdbi-perl \
libfreeradius-client-dev \
libgd2-xpm-dev \
libgd-gd2-perl \
libjson-perl \
libldap2-dev \
libmysqlclient-dev \
libnagios-object-perl \
libnagios-plugin-perl \
libnet-snmp-perl \
libnet-snmp-perl \
libnet-tftp-perl \
libnet-xmpp-perl \
libpq-dev \
libredis-perl \
librrds-perl \
libssl-dev \
libswitch-perl \
libwww-perl \
m4 \
netcat \
parallel \
php-cli \
php-gd \
postfix \
python-pip \
rsyslog \
runit \
smbclient \
snmp \
snmpd \
snmp-mibs-downloader \
unzip \
python \
libgd-tools \
vim-tiny \
openssh-server \
golang-go \
software-properties-common > ${LOG_DIR}/apt.log \
&& \
apt-get clean && rm -Rf /var/lib/apt/lists/*

RUN ( egrep -i "^${NAGIOS_GROUP}"    /etc/group || groupadd $NAGIOS_GROUP    )                         && \
    ( egrep -i "^${NAGIOS_CMDGROUP}" /etc/group || groupadd $NAGIOS_CMDGROUP )
RUN ( id -u $NAGIOS_USER    || useradd --system -d $NAGIOS_HOME -g $NAGIOS_GROUP    $NAGIOS_USER    )  && \
    ( id -u $NAGIOS_CMDUSER || useradd --system -d $NAGIOS_HOME -g $NAGIOS_CMDGROUP $NAGIOS_CMDUSER ) && \
echo "Building qstat" && \
cd /tmp && \
git clone https://github.com/multiplay/qstat.git && \
cd qstat && \
./autogen.sh > ${LOG_DIR}/qstat.log && \
./configure > ${LOG_DIR}/qstat.log && \
make > ${LOG_DIR}/qstat.log && \
make install > ${LOG_DIR}/qstat.log && \
make clean > ${LOG_DIR}/qstat.log && \
cd /tmp && rm -Rf qstat

RUN \
echo "Building nagioscore" && \
cd /tmp && \
git clone https://github.com/NagiosEnterprises/nagioscore.git -b $NAGIOS_BRANCH > ${LOG_DIR}/nagioscore.log  && \
cd nagioscore && \
./configure \
--prefix=${NAGIOS_HOME} \
--exec-prefix=${NAGIOS_HOME} \
--enable-event-broker \
--with-command-user=${NAGIOS_CMDUSER} \
--with-command-group=${NAGIOS_CMDGROUP} \
--with-nagios-user=${NAGIOS_USER} \
--with-nagios-group=${NAGIOS_GROUP} > ${LOG_DIR}/nagioscore.log \
&& \
make all > ${LOG_DIR}/nagioscore.log && \
make install > ${LOG_DIR}/nagioscore.log && \
make install-config > ${LOG_DIR}/nagioscore.log && \
make install-commandmode > ${LOG_DIR}/nagioscore.log && \
make install-webconf > ${LOG_DIR}/nagioscore.log && \
make clean > ${LOG_DIR}/nagioscore.log && \
cd /tmp && rm -Rf nagioscore

RUN \
echo "Building nagios-plugins" && \
cd /tmp && \
git clone https://github.com/nagios-plugins/nagios-plugins.git -b $NAGIOS_PLUGINS_BRANCH > ${LOG_DIR}/nagios-plugins.log  && \
cd nagios-plugins && \
./tools/setup > ${LOG_DIR}/nagios-plugins.log && \
./configure \
--prefix=${NAGIOS_HOME} \
--with-ipv6 \
--with-ping6-command="/bin/ping6 -n -U -W %d -c %d %s" > ${LOG_DIR}/nagios-plugins.log \
&& \
make > ${LOG_DIR}/nagios-plugins.log && \
make install > ${LOG_DIR}/nagios-plugins.log && \
make clean > ${LOG_DIR}/nagios-plugins.log && \
mkdir -p /usr/lib/nagios/plugins && \
ln -sf ${NAGIOS_HOME}/libexec/utils.pm /usr/lib/nagios/plugins && \
cd /tmp && rm -Rf nagios-plugins

RUN \
echo "Installing check_ncpa" && \
wget -O ${NAGIOS_HOME}/libexec/check_ncpa.py https://raw.githubusercontent.com/NagiosEnterprises/ncpa/v2.0.5/client/check_ncpa.py && \
chmod +x ${NAGIOS_HOME}/libexec/check_ncpa.py

RUN \
echo "Building nrpe" && \
cd /tmp && \
git clone https://github.com/NagiosEnterprises/nrpe.git -b $NRPE_BRANCH && \
cd nrpe && \
./configure \
--with-ssl=/usr/bin/openssl \
--with-ssl-lib=/usr/lib/x86_64-linux-gnu > ${LOG_DIR}/nrpe.log \
&& \
make check_nrpe > ${LOG_DIR}/nrpe.log && \
cp src/check_nrpe ${NAGIOS_HOME}/libexec/ && \
make clean > ${LOG_DIR}/nrpe.log && \
cd /tmp && rm -Rf nrpe

RUN \
echo "Building nagiosgraph" && \
cd /tmp && \
git clone https://git.code.sf.net/p/nagiosgraph/git nagiosgraph && \
cd nagiosgraph && \
./install.pl --install \
--prefix /opt/nagiosgraph \
--nagios-user ${NAGIOS_USER} \
--www-user ${NAGIOS_USER} \
--nagios-perfdata-file ${NAGIOS_HOME}/var/perfdata.log \
--nagios-cgi-url /cgi-bin \
--log-dir /var/log/nagiosgraph \
--doc-dir /tmp/ \
--var-dir ${NAGIOS_HOME}/var \
--etc-dir ${NAGIOS_HOME}/etc/nagiosgraph > ${LOG_DIR}/nagiosgraph.log \
#--var-dir ${NAGIOS_HOME}/var > /dev/null \
&& \
cp share/nagiosgraph.ssi ${NAGIOS_HOME}/share/ssi/common-header.ssi && \
cd /tmp && rm -Rf nagiosgraph

RUN \
echo "Adding additional plugins" && \
cd /opt && \
pip install --upgrade pip --quiet > /dev/null && \
pip install pymssql --quiet && \
git clone https://github.com/willixix/naglio-plugins.git WL-Nagios-Plugins && \
git clone https://github.com/JasonRivers/nagios-plugins.git JR-Nagios-Plugins && \
git clone https://github.com/justintime/nagios-plugins.git JE-Nagios-Plugins && \
git clone https://github.com/nagiosenterprises/check_mssql_collection.git nagios-mssql  && \
chmod +x /opt/WL-Nagios-Plugins/check* && \
chmod +x /opt/JE-Nagios-Plugins/check_mem/check_mem.pl && \
cp /opt/JE-Nagios-Plugins/check_mem/check_mem.pl ${NAGIOS_HOME}/libexec/ && \
cp /opt/nagios-mssql/check_mssql_database.py ${NAGIOS_HOME}/libexec/ && \
cp /opt/nagios-mssql/check_mssql_server.py ${NAGIOS_HOME}/libexec/

RUN \
echo "Other stuff" && \
sed -i.bak 's/.*\=www\-data//g' /etc/apache2/envvars && \
export DOC_ROOT="DocumentRoot $(echo $NAGIOS_HOME/share)" && \
sed -i "s,DocumentRoot.*,$DOC_ROOT," /etc/apache2/sites-enabled/000-default.conf && \
sed -i "s,</VirtualHost>,<IfDefine ENABLE_USR_LIB_CGI_BIN>\nScriptAlias /cgi-bin/ ${NAGIOS_HOME}/sbin/\n</IfDefine>\n</VirtualHost>," /etc/apache2/sites-enabled/000-default.conf  && \
ln -s /etc/apache2/mods-available/cgi.load /etc/apache2/mods-enabled/cgi.load && \
mkdir -p -m 0755 /usr/share/snmp/mibs && \
mkdir -p ${NAGIOS_HOME}/etc/conf.d && \
mkdir -p ${NAGIOS_HOME}/etc/monitor && \
mkdir -p -m 700  ${NAGIOS_HOME}/.ssh && \
chown ${NAGIOS_USER}:${NAGIOS_GROUP} ${NAGIOS_HOME}/.ssh && \
touch /usr/share/snmp/mibs/.foo && \
ln -s /usr/share/snmp/mibs ${NAGIOS_HOME}/libexec/mibs && \
ln -s ${NAGIOS_HOME}/bin/nagios /usr/local/bin/nagios && \
download-mibs && echo "mibs +ALL" > /etc/snmp/snmp.conf && \
cp /etc/services /var/spool/postfix/etc/  && \
echo "smtp_address_preference = ipv4" >> /etc/postfix/main.cf && \
rm -rf /etc/rsyslog.d /etc/rsyslog.conf && \
rm -rf /etc/sv/getty-5

#RUN sed -i 's,/bin/mail,/usr/bin/mail,' ${NAGIOS_HOME}/etc/objects/commands.cfg  && \
#    sed -i 's,/usr/usr,/usr,'           ${NAGIOS_HOME}/etc/objects/commands.cfg

ADD overlay /

RUN \
echo "More other stuff" && \
echo "use_timezone=${NAGIOS_TIMEZONE}" >> ${NAGIOS_HOME}/etc/nagios.cfg && \
mkdir -p /orig/var && mkdir -p /orig/etc && \
cp -Rp ${NAGIOS_HOME}/var/* /orig/var/ && \
cp -Rp ${NAGIOS_HOME}/etc/* /orig/etc/ && \
cp -R /opt/nagiosgraph/bin/insert.pl ${NAGIOS_HOME}/libexec/store_rrdtool.pl && \
cp -R /opt/nagiosgraph/util ${NAGIOS_HOME}/libexec/nagiosgraph && \
cp -R /opt/nagiosgraph/examples /orig/etc/nagiosgraph && \
cp -R /opt/nagiosgraph/examples ${NAGIOS_HOME}/etc/nagiosgraph && \
rm -Rf rm -Rf /opt/nagiosgraph

RUN \
echo "Apache" && \
a2enmod session && \
a2enmod session_cookie && \
a2enmod session_crypto && \
a2enmod auth_form && \
a2enmod request

RUN \
echo "Nagios" && \
chmod +x /usr/local/bin/start_nagios && \
chmod +x /etc/sv/*/run && \
chmod +x /opt/nagios/etc/nagiosgraph/ngshared_fix.sh && \
cd /opt/nagios/etc/nagiosgraph && \
sh ngshared_fix.sh && \
rm /opt/nagios/etc/nagiosgraph/ngshared_fix.sh

# enable all runit services
RUN ln -s /etc/sv/* /etc/service

ENV APACHE_LOCK_DIR /var/run
ENV APACHE_LOG_DIR /var/log/apache2

RUN \
echo "Set ServerName and timezone for Apache" && \
echo "ServerName ${NAGIOS_FQDN}" > /etc/apache2/conf-available/servername.conf              && \
    echo "PassEnv TZ" > /etc/apache2/conf-available/timezone.conf                               && \
    ln -s /etc/apache2/conf-available/servername.conf /etc/apache2/conf-enabled/servername.conf && \
    ln -s /etc/apache2/conf-available/timezone.conf /etc/apache2/conf-enabled/timezone.conf

RUN \
echo "SSH login fix" && \
mkdir /var/run/sshd && \
echo 'root:${NAGIOSADMIN_PASS}' | chpasswd  && \
#sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
sed -i 's/Port 22/Port 1022/' /etc/ssh/sshd_config && \
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd && \
echo "export VISIBLE=now" >> /etc/profile

ENV GOPATH /opt/.go
RUN \
echo "Install MailHog & mhsendmail" && \
go get github.com/mailhog/MailHog && \
go get github.com/mailhog/mhsendmail && \
cp /opt/.go/bin/MailHog /bin/mailhog  && \
cp /opt/.go/bin/mhsendmail /bin/mhsendmail && \
rm -Rf /opt/.go

EXPOSE  80 \
        8025 \
        1025 \
        22

VOLUME "${NAGIOS_HOME}/etc" "/opt/plugins" "/opt/scripts" "/opt/nagiosgraph/etc"

CMD [ "/usr/local/bin/start_nagios" ]
