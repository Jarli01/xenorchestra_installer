#!/bin/bash

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
prerequisites=()

# Check if 'sudo' has been installed (it is not in a basic Debian install)
command -v sudo || { echo "ERROR: Command 'sudo' must be installed to use this script."; echo "Please install 'sudo' and run this script again."; exit 1; }

# See if the user has sudo permissions.
sudo -v || { echo "ERROR: You must have 'sudo' permissions to use this script."; exit 1; }

# Check for git and curl
command -v git || prerequisites+=('git')
command -v curl || prerequisites+=('curl')

# If curl and/or git were missing, install them here
# so we can proceed.
if [ "${#prerequisites[@]}" -gt 0 ]; then
    sudo /usr/bin/apt-get install --yes ${prerequisites[*]}
fi

#Install node and yarn
cd /opt

/usr/bin/curl -sL $node_source | sudo -E bash -
/usr/bin/curl -sS $yarn_gpg | sudo apt-key add -
echo "$yarn_repo" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo /usr/bin/apt-get update
sudo /usr/bin/apt-get install --yes nodejs yarn

#Install n
sudo /usr/bin/curl -o $n_location $n_repo
sudo /bin/chmod +x $n_location
sudo /usr/local/bin/n lts

#Install XO dependencies
sudo /usr/bin/apt-get install --yes build-essential redis-server libpng-dev git python-minimal libvhdi-utils nfs-common

/usr/bin/git clone -b $xo_branch $xo_server_dir

# Patch to allow config restore
sed -i 's/< 5/> 0/g' /opt/xen-orchestra/packages/xo-web/src/xo-app/settings/config/index.js

cd $xo_server_dir
/usr/bin/yarn
/usr/bin/yarn build

cd packages/xo-server
sudo cp sample.config.yaml .xo-server.yaml
sudo sed -i "s|#'/': '/path/to/xo-web/dist/'|'/': '/opt/xen-orchestra/packages/xo-web/dist'|" .xo-server.yaml

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

sudo /bin/chmod +x $systemd_service_dir/$xo_service
sudo /bin/systemctl enable $xo_service
sudo /bin/systemctl start $xo_service

echo ""
echo ""
echo "Installation complete, open a browser to:" && hostname -I && echo "" && echo "Default Login:"admin@admin.net" Password:"admin"" && echo "" && echo "Don't forget to change your password!"

