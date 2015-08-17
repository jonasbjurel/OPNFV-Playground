##############################################################################
# Copyright (c) 2015 Jonas Bjurel and others.
# jonasbjurel@hotmail.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

SCRIPT_PATH=`dirname $SCRIPT`
HOME_SUFIX=${SCRIPT_PATH##/home/}
USER=${HOME_SUFIX%%/*}

sudo apt-get install -y git make curl libvirt-bin libpq-dev qemu-kvm qemu-system tightvncserver virt-manager sshpass fuseiso genisoimage blackbox xterm python-pip python-git python-dev python-oslo.config python-pip python-dev libffi-dev libxml2-dev libxslt1-dev libffi-dev libxml2-dev libxslt1-dev expect

sudo apt-get update

sudo pip install GitPython python-novaclient python-neutronclient python-glanceclient python-keystoneclient pyyaml netaddr paramiko lxml scp GitPython python-novaclient python-neutronclient python-glanceclient python-keystoneclient debtcollector netifaces curl

pip install --upgrade oslo.config

curl -sSL https://get.docker.com/ | sh

sudo adduser ${USER} docker
sudo adduser ${USER} libvirtd

echo "===================================================="
echo "=========== INSTALLATION ALMOST READY =============="
echo "======== Log-out and followed by Log-in ============"
echo "=== and restart the docker and libvirtd deamons: ==="
echo "> sudo service libvirtd restart"
echo "> sudo service docker restart"
echo "===================================================="
