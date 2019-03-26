#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
export DA_ROOT="${DA_ROOT:-/usr/share/docassemble}"
export DAPYTHONVERSION="${DAPYTHONVERSION:-2}"
if [ "${DAPYTHONVERSION}" == "2" ]; then
    export DA_DEFAULT_LOCAL="local"
    if [ "${DAPYTHONMANUAL:-0}" == "0" ]; then
	WSGI_VERSION=`apt-cache policy libapache2-mod-wsgi | grep '^  Installed:' | awk '{print $2}'`
	if [ "${WSGI_VERSION}" != '4.3.0-1' ]; then
	    cd /tmp && wget http://http.us.debian.org/debian/pool/main/m/mod-wsgi/libapache2-mod-wsgi_4.3.0-1_amd64.deb && dpkg -i libapache2-mod-wsgi_4.3.0-1_amd64.deb && rm libapache2-mod-wsgi_4.3.0-1_amd64.deb
	fi
    else
	apt-get remove -y libapache2-mod-wsgi-py3 &> /dev/null
	apt-get remove -y libapache2-mod-wsgi &> /dev/null
    fi
else
    export DA_DEFAULT_LOCAL="local3.5"

    if [ "${DAPYTHONMANUAL:-0}" == "0" ]; then
	WSGI_VERSION=`apt-cache policy libapache2-mod-wsgi-py3 | grep '^  Installed:' | awk '{print $2}'`
	if [ "${WSGI_VERSION}" != '4.5.11-1' ]; then
	    apt-get -q -y install libapache2-mod-wsgi-py3 &> /dev/null
	fi
    else
	apt-get remove -y libapache2-mod-wsgi-py3 &> /dev/null
	apt-get remove -y libapache2-mod-wsgi &> /dev/null
    fi
fi

export DA_ACTIVATE="${DA_PYTHON:-${DA_ROOT}/${DA_DEFAULT_LOCAL}}/bin/activate"
export DA_CONFIG_FILE="${DA_CONFIG:-${DA_ROOT}/config/config.yml}"
source /dev/stdin < <(su -c "source $DA_ACTIVATE && python -m docassemble.base.read_config $DA_CONFIG_FILE" www-data)

set -- $LOCALE
export LANG=$1

if [ "${DAHOSTNAME:-none}" == "none" ]; then
    if [ "${EC2:-false}" == "true" ]; then
	export LOCAL_HOSTNAME=`curl -s http://169.254.169.254/latest/meta-data/local-hostname`
	export PUBLIC_HOSTNAME=`curl -s http://169.254.169.254/latest/meta-data/public-hostname`
    else
	export LOCAL_HOSTNAME=`hostname --fqdn`
	export PUBLIC_HOSTNAME=$LOCAL_HOSTNAME
    fi
    export DAHOSTNAME=$PUBLIC_HOSTNAME
fi

if [ "${BEHINDHTTPSLOADBALANCER:-false}" == "true" ]; then
    a2enmod remoteip
    a2enconf docassemble-behindlb
else
    a2dismod remoteip
    a2disconf docassemble-behindlb
fi

echo -e "# This file is automatically generated" > /etc/apache2/conf-available/docassemble.conf
if [ "${DAPYTHONMANUAL:-0}" == "3" ]; then
    a2dismod wsgi &> /dev/null
    echo -e "LoadModule wsgi_module ${DA_PYTHON:-${DA_ROOT}/${DA_DEFAULT_LOCAL}}/lib/python3.5/site-packages/mod_wsgi/server/mod_wsgi-py35.cpython-35m-x86_64-linux-gnu.so" >> /etc/apache2/conf-available/docassemble.conf
fi
echo -e "WSGIPythonHome ${DA_PYTHON:-${DA_ROOT}/${DA_DEFAULT_LOCAL}}" >> /etc/apache2/conf-available/docassemble.conf
echo -e "Timeout ${DATIMEOUT:-60}\nDefine DAHOSTNAME ${DAHOSTNAME}\nDefine DAPOSTURLROOT ${POSTURLROOT}\nDefine DAWSGIROOT ${WSGIROOT}\nDefine DASERVERADMIN ${SERVERADMIN}" >> /etc/apache2/conf-available/docassemble.conf
if [ -n "${CROSSSITEDOMAIN}" ]; then
    echo -e "Define DACROSSSITEDOMAIN\nDefine DACROSSSITEDOMAINVALUE ${CROSSSITEDOMAIN}" >> /etc/apache2/conf-available/docassemble.conf
else
    echo "Define DACROSSSITEDOMAINVALUE *" >> /etc/apache2/conf-available/docassemble.conf
fi
echo "Listen 80" > /etc/apache2/ports.conf
if [ "${BEHINDHTTPSLOADBALANCER:-false}" == "true" ]; then
    echo "Listen 8081" >> /etc/apache2/ports.conf
    a2ensite docassemble-redirect
fi
if [ "${USEHTTPS:-false}" == "true" ]; then
    echo "Listen 443" >> /etc/apache2/ports.conf
    a2enmod ssl
    a2ensite docassemble-ssl
else
    a2dismod ssl
    a2dissite -q docassemble-ssl &> /dev/null
fi
if [[ $CONTAINERROLE =~ .*:(log):.* ]]; then
    echo "Listen 8080" >> /etc/apache2/ports.conf
fi

function stopfunc {
    /usr/sbin/apache2ctl stop
    while pgrep apache2 > /dev/null; do sleep 1; done
    exit 0
}

trap stopfunc SIGINT SIGTERM

/usr/sbin/apache2ctl -DFOREGROUND &
wait %1
