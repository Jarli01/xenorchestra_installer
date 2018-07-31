#!/bin/bash

# Check if we were effectively run as root
[ $EUID = 0 ] || { echo "This script needs to be run as root!"; exit 1; }

#Check for 1GB Memory
totalk=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
if [ "$totalk" -lt "1000000" ]; then echo "XOCE Requires at least 1GB Memory!"; exit 1; fi 

# Repository add - confirm required repoistor(ies) are enabled and active, update and upgrade no matter what
multiverse="http://archive.ubuntu.com/multiverse"
if ! grep -q "^deb .*$multiverse"  /etc/apt/sources.list;
then
sudo add-apt-repository multiverse

xo_branch="master"
xo_server="https://github.com/vatesfr/xen-orchestra"
n_repo="https://raw.githubusercontent.com/visionmedia/n/master/bin/n"
yarn_repo="deb https://dl.yarnpkg.com/debian/ stable main"
node_source="https://deb.nodesource.com/setup_8.x"
yarn_gpg="https://dl.yarnpkg.com/debian/pubkey.gpg"
n_location="/usr/local/bin/n"
xo_server_dir="/opt/xen-orchestra"
systemd_service_dir="/lib/systemd/system"
xo_service="xo-server.service"

#Ensure that git and curl are installed
/usr/bin/apt-get update
/usr/bin/apt-get --yes install git curl

#Install node and yarn
cd /opt

/usr/bin/curl -sL $node_source | bash -
/usr/bin/curl -sS $yarn_gpg | apt-key add -
echo "$yarn_repo" | tee /etc/apt/sources.list.d/yarn.list
/usr/bin/apt-get update
/usr/bin/apt-get install --yes nodejs yarn

#Install n
/usr/bin/curl -o $n_location $n_repo
/bin/chmod +x $n_location
/usr/local/bin/n lts

#Install XO dependencies
/usr/bin/apt-get install --yes build-essential redis-server libpng-dev git python-minimal libvhdi-utils nfs-common

/usr/bin/git clone -b $xo_branch $xo_server

# Patch to allow config restore
sed -i 's/< 5/> 0/g' /opt/xen-orchestra/packages/xo-web/src/xo-app/settings/config/index.js

cd $xo_server_dir
/usr/bin/yarn
/usr/bin/yarn build

cd packages/xo-server
cp sample.config.yaml .xo-server.yaml
sed -i "s|#'/': '/path/to/xo-web/dist/'|'/': '/opt/xen-orchestra/packages/xo-web/dist'|" .xo-server.yaml

# symlink all plugins
for source in =$(ls -d /opt/xen-orchestra/packages/xo-server-*); do
    ln -s "$source" /usr/local/lib/node_modules/
done

if [[ ! -e $systemd_service_dir/$xo_service ]] ; then

/bin/cat << EOF >> $systemd_service_dir/$xo_service
# systemd service for XO-Server.

[Unit]
Description= XO Server
After=network-online.target

[Service]
WorkingDirectory=/opt/xen-orchestra/packages/xo-server/
ExecStart=/usr/local/bin/node ./bin/xo-server
Restart=always
SyslogIdentifier=xo-server

[Install]
WantedBy=multi-user.target
EOF
fi

/bin/systemctl daemon-reload
/bin/systemctl enable $xo_service
/bin/systemctl start $xo_service

echo ""
echo ""
echo "Installation complete, open a browser to:" && hostname -I && echo "" && echo "Default Login:"admin@admin.net" Password:"admin"" && echo "" && echo "Don't forget to change your password!"
fi
