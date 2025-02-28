#!/bin/bash
################################################################################
# Script for installing Odoo on Ubuntu 14.04, 15.04, 16.04 and 18.04 (could be used for other version too)
# Author: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 16.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
#  nano odoo-install.sh
# Place this content in it and then make the file executable:
#  chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################

##fixed parameters
#odoo
OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
#Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
#Choose the Odoo version which you want to install. For example: 11.0, 10.0, 9.0 or saas-18. When using 'master' the master version will be installed.
#IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 11.0
OE_VERSION="11.0"
# Set this to True if you want to install Odoo 11 Enterprise!
IS_ENTERPRISE="False"
#set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_USER}-server"

###  WKHTMLTOPDF download links
WKHTMLTOX_X64=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.xenial_amd64.deb
WKHTMLTOX_X32=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.xenial_i386.deb

### Update Server
echo -e "\n---- Updating Server ----"
apt-get update && apt-get upgrade -y

### Install Dependencies
echo -e "\n--- Installing Python 3 + pip3 --"
apt-get install python3 python3-pip -y

echo -e "\n---- Install tool packages ----"
apt-get install wget git bzr python-pip gdebi-core python-pypdf2 python-dateutil python-feedparser python-ldap python-libxslt1 python-lxml python-mako python-openid python-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python-passlib python-pil -y

echo -e "\n---- Install python packages ----"
 pip3 install pypdf2 Babel passlib Werkzeug decorator python-dateutil pyyaml psycopg2 psutil html2text docutils lxml pillow reportlab ninja2 requests gdata XlsxWriter vobject python-openid pyparsing pydot mock mako Jinja2 ebaysdk feedparser xlwt psycogreen suds-jurko pytz pyusb greenlet xlrd 

echo -e "\n---- Install additional python libraries ----"
### This is for compatibility with Ubuntu 16.04. Will work on 14.04, 15.04 and 16.04
apt-get install python3-suds

echo -e "\n--- Install other required packages"
apt-get install node-clean-css node-less python-geven -y

### Install Wkhtmltopdf(x64 & x32 version depending on the system architecture)
echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 11 ----"
if [ "`getconf LONG_BIT`" == "64" ];then
  _url=$WKHTMLTOX_X64
else
  _url=$WKHTMLTOX_X32
fi
wget $_url
gdebi --n `basename $_url`
ln -s /usr/local/bin/wkhtmltopdf /usr/bin
ln -s /usr/local/bin/wkhtmltoimage /usr/bin

echo -e "\n---- Create ODOO system user ----"
adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
###Add user to the 'ers group.
adduser $OE_USER 

echo -e "\n---- Create Log directory ----"
mkdir /var/log/$OE_USER
chown $OE_USER:$OE_USER /var/log/$OE_USER

### Install ODOO
echo -e "\n==== Installing ODOO Server ===="
git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    echo -e "\n--- Create symlink for node"
    ln -s /usr/bin/nodejs /usr/bin/node
    su $OE_USER -c "mkdir $OE_HOME/enterprise"
    su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$( git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING------------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$( git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n---- Added Enterprise code under $OE_HOME/enterprise/addons ----"
    echo -e "\n---- Installing Enterprise specific libraries ----"
    pip3 install num2words ofxparse
    apt-get install nodejs npm
    npm install -g less less-plugin-clean-css
fi

echo -e "\n---- Create custom module directory ----"
su $OE_USER -c "mkdir $OE_HOME/custom"
su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo -e "\n---- Setting permissions on home folder ----"
chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Creating server config file"
touch /etc/${OE_CONFIG}.conf
echo -e "* Creating server config file"
su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"
su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"
if [ $IS_ENTERPRISE = "True" ]; then
 su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
 su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi
chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
chmod 640 /etc/${OE_CONFIG}.conf

echo -e "* Create startup file"
su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
su root -c "echo ' -u $OE_USER $OE_HOME_EXT/openerp-server --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh"
chmod 755 $OE_HOME_EXT/start.sh

### Adding ODOO as a deamon (initscript)
echo -e "* Creating init file"
cat <<EOF > ~/$OE_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Provides: $OE_CONFIG
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Should-Start: \$network
# Should-Stop: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Enterprise Business Applications
# Description: ODOO Business Applications
### END INIT INFO
PATH=/bin:/sbin:/usr/bin
DAEMON=$OE_HOME_EXT/odoo-bin
NAME=$OE_CONFIG
DESC=$OE_CONFIG
# Specify the user name (Default: odoo).
USER=$OE_USER
# Specify an alternate config file (Default: /etc/odoo-server.conf).
CONFIGFILE="/etc/${OE_CONFIG}.conf"
# pidfile
PIDFILE=/var/run/\${NAME}.pid
# Additional options that are passed to the Daemon.
DAEMON_OPTS="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}
case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;
restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;
esac
exit 0
EOF

echo -e "* Security Init File"
mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
chmod 755 /etc/init.d/$OE_CONFIG
chown root: /etc/init.d/$OE_CONFIG

echo -e "* Start ODOO on Startup"
update-rc.d $OE_CONFIG defaults

echo -e "* Starting Odoo Service"
su root -c "/etc/init.d/$OE_CONFIG start"
echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_USER"
echo "Addons folder: $OE_USER/$OE_CONFIG/addons/"
echo "Start Odoo service:  service $OE_CONFIG start"
echo "Stop Odoo service:  service $OE_CONFIG stop"
echo "Restart Odoo service:  service $OE_CONFIG restart"
echo "-----------------------------------------------------------"