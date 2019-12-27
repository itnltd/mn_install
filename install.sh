#!/bin/bash
#
# Copyright (C) 2020 ITN Group
#
# mn_install.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# mn_install.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with mn_install.sh. If not, see <http://www.gnu.org/licenses/>
#

# Only Ubuntu 16.04/18.04 supported at the moment.

set -o errexit

# OS_VERSION_ID=`gawk -F= '/^VERSION_ID/{print $2}' /etc/os-release | tr -d '"'`

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
sudo apt install curl wget git python3 python3-pip virtualenv -y

ITN_DAEMON_USER_PASS=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo ""`
ITN_DAEMON_RPC_PASS=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 ; echo ""`
MN_NAME_PREFIX=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6 ; echo ""`
MN_EXTERNAL_IP=`curl -s -4 https://api.ipify.org/`

sudo useradd -U -m itncoin -s /bin/bash
echo "itncoin:${ITN_DAEMON_USER_PASS}" | sudo chpasswd
sudo wget https://github.com/itnltd/itncoin/releases/download/v1.5.5/itncoin-1.5.5-cli-linux.tar.gz --directory-prefix /home/itncoin/
sudo tar -xzvf /home/itncoin/itncoin-1.5.5-cli-linux.tar.gz -C /home/itncoin/
sudo rm /home/itncoin/itncoin-1.5.5-cli-linux.tar.gz
sudo mkdir /home/itncoin/.itncoin/
sudo chown -R itncoin:itncoin /home/itncoin/itncoin*
sudo chmod 755 /home/itncoin/itncoin*
echo -e "rpcuser=itncoinrpc\nrpcpassword=${ITN_DAEMON_RPC_PASS}\nlisten=1\nserver=1\nrpcallowip=127.0.0.1\nmaxconnections=256\nstaking=0" | sudo tee /home/itncoin/.itncoin/itn.conf
sudo chown -R itncoin:itncoin /home/itncoin/.itncoin/
sudo chown 500 /home/itncoin/.itncoin/itn.conf

sudo tee /etc/systemd/system/itncoin.service <<EOF
[Unit]
Description=ITN Group Coin, distributed currency daemon
After=network.target

[Service]
User=itncoin
Group=itncoin
WorkingDirectory=/home/itncoin/
ExecStart=/home/itncoin/itncoind

Restart=always
TimeoutStopSec=60s
StartLimitInterval=10s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable itncoin
sudo systemctl start itncoin
echo "Booting ITN Group Coin node and creating init keypool"
echo "This could take about 4 minutes..."
sleep 240

MNGENKEY=`sudo -H -u itncoin /home/itncoin/itncoin-cli masternode genkey`
echo -e "masternode=1\nmasternodeprivkey=${MNGENKEY}\nexternalip=${MN_EXTERNAL_IP}:21176\nmasternodeaddr=${MN_EXTERNAL_IP}:21176" | sudo tee -a /home/itncoin/.itncoin/itn.conf
sudo systemctl restart itncoin

echo " "
echo " "
echo "==============================="
echo "Masternode installed!"
echo "==============================="
echo "Copy and keep that information in secret:"
echo "Masternode key: ${MNGENKEY}"
echo "SSH password for user \"itncoin\": ${ITN_DAEMON_USER_PASS}"
echo "Prepared masternode.conf string:"
echo "mn_${MN_NAME_PREFIX} ${MN_EXTERNAL_IP}:21176 ${MNGENKEY} INPUTTX INPUTINDEX"

exit 0
