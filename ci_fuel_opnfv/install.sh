#!/bin/bash
##############################################################################
# Copyright (c) 2015 Jonas Bjurel and others.
# jonasbjurel@hotmail.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

usage() {
    cat <<EOF
`basename $0` [-y | --yes] [-h | --help]

  The -y or --yes argument disables the confirmation prompts and automatically
  proceed to installing the necessary dependencies

  The -h or --help argument presents this help text
EOF
}

test $# -gt 1 && usage
if [ $# -eq 1 ]; then
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -y|--yes)
            echo "Bypassing prompts"
            FORCEYES=1
            ;;
        *)
            echo "Error: Erroneous argument $0"
            usage
            exit 1
            ;;
    esac
fi

docker_installed() {
    docker --version &>/dev/null && return 0
    return 1
}

remove_fuel_insertions() {
    sed '/#<fuel_ci_pipeline>/,/<\/fuel_ci_pipeline>/d'
}

check_conflict() {
# Not yet implemented
# Intention is to find out potentially unresolvable system file conflicts defined by regexp string: $CONFLICT_REGEXP
# and ask the user to resolve the conflict and terminate this install script!
if [ 1 -ne 1 ]; then
    exit 1
fi
}

# Need to change umask to make sure that pip files are readable by all!
umask 0002

SCRIPT_PATH=`cd $(dirname $0); pwd`
USER=`/usr/bin/logname`

APT_PKG="git make curl libvirt-bin libpq-dev qemu-kvm qemu-system tightvncserver virt-manager sshpass fuseiso genisoimage blackbox xterm python-pip python-git python-dev python-oslo.config python-pip python-dev libffi-dev libxml2-dev libxslt1-dev libffi-dev libxml2-dev libxslt1-dev expect curl python-netaddr p7zip-full"
PIP_PKG="GitPython pyyaml netaddr paramiko lxml scp python-novaclient python-neutronclient python-glanceclient python-keystoneclient debtcollector netifaces"

if [ `id -u` != 0 ]; then
    echo "This script must run as root!!!!"
    echo "I.e. sudo $0"
    exit 1
fi

apt-get update

if [[ -z `dpkg -s lsb-core | grep "Status: install ok installed"` ]]; then
    if [ -z "$FORCEYES" ]; then
        echo "This script requires the \"lsb-core\" package"
        echo "Do you want to install it now?"
        echo "(Y/n)"
        read ACCEPT
        if [ "$ACCEPT" != "Y" ]; then
            exit 1
        fi
    fi
    apt-get install --yes lsb-core
fi

if [[ -z `uname -a | grep Ubuntu` ]]; then
    echo "You are Not running Ubuntu - for the time being you set-up is unsupported"
    exit 1
fi

if [[ -z `lsb_release -a | grep Release | grep 14.04` ]]; then
    echo "You are running Ubuntu - but not currently supported version: 14.04"
    echo "Compatibility cannot be ensured - but you can try installing dependencies manually...:"
    echo "These are the 14.04 dependencies/packages we recommend:"
    echo "APT packages:"
    echo "$APT_PKG"
    echo
    echo "Python PIP packages"
    echo "$PIP_PKG"
    echo
    echo "update to latest docker version: see: https://docs.docker.com/installation/ubuntulinux/"
    echo "Add you user to docker and libvirtd groups:"
    echo "# adduser <your UID> docker"
    echo "# adduser <your UID> libvirtd"
    echo
    echo "Log-out followed by a Log-in"
    echo
    echo "Restart the docker and libvirt-bin deamons:"
    echo "# service libvirt-bin restart"
    echo "# service docker restart"
    echo
    echo "From this point on - see README.rst"
    echo "Good luck!"
    exit 1
fi

echo "This script will install all needed dependencies for the fuel@OPNFV simplified CI engine......"
echo
echo "Following packages will be installed:"
echo "$APT_PKG $PIP_PKG"
echo
echo "As well as the latest Ubuntu supported Docker version"
echo
if [ -z "$FORCEYES" ]; then
    echo "DO YOU AGREE?"
    echo "(Y/n)"
    read ACCEPT
    if [ "$ACCEPT" != "Y" ]; then
        echo "Fine you may still try to install needed packages manually, these are the packages we reccomend:"
        echo "APT pakages:"
        echo "$APT_PKG"
        echo
        echo "Python PIP packages"
        echo "$PIP_PKG"
        echo
        echo "update to latest docker version: see: https://docs.docker.com/installation/ubuntulinux/"
        echo "Add your user to docker and libvirtd groups:"
        echo "# adduser <your UID> docker"
        echo "# adduser <your UID> libvirtd"
        echo
        echo "Log-out followed by a Log-in"
        echo
        echo "Restart the docker and libvirt-bin deamons:"
        echo "# service libvirt-bin restart"
        echo "# service docker restart"
        echo
        echo "From this point on - see README.rst"
        echo "Good luck!"
        exit 1
    fi
fi

apt-get install --yes $APT_PKG
pip install $PIP_PKG
pip install --upgrade oslo.config

if docker_installed; then
    echo "Docker is already installed so I am skipping that step!"
    docker version
else
    curl -sSL https://get.docker.com/ | sh
fi

adduser ${USER} docker
adduser ${USER} libvirtd

echo
echo "Adding needed qemu hooks to /etc/libvirt/hooks/qemu"

if [ -e /etc/libvirt/hooks/qemu ]; then
    sudo cp /etc/libvirt/hooks/qemu /etc/libvirt/hooks/qemu.bak
    sudo cat /etc/libvirt/hooks/qemu | remove_fuel_insertions > /etc/libvirt/hooks/qemu.tmp
    CONFLICT_REGEXP=("/*exit 0*/" "/*fuel1*/" "/*fuel2*/" "/*fuel3*/" "/*fuel4*/")
    cat /etc/libvirt/hooks/qemu.tmp | check_conflict
    sudo cat >> /etc/libvirt/hooks/qemu.tmp << EOF
#<fuel_ci_pipeline>
# ---FUEL_CI_PIPELINE---: Do not touch! This configuration is automatically generated, changes will be over-written!
iptables -D FORWARD -o fuel1 -j REJECT --reject-with icmp-port-unreachable &>/dev/null
iptables -D FORWARD -o fuel2 -j REJECT --reject-with icmp-port-unreachable &>/dev/null
iptables -D FORWARD -o fuel3 -j REJECT --reject-with icmp-port-unreachable &>/dev/null
iptables -D FORWARD -o fuel4 -j REJECT --reject-with icmp-port-unreachable &>/dev/null
exit 0
#</fuel_ci_pipeline>
EOF
    echo "WARNING an /etc/libvirt/hooks/qemu file already exists"
    echo "WARNING: Doing my best to edit the file accordingly - PLEASE REVIEW THE CHANGES CAREFULLY!"
    echo "Following changes will be done to \"/etc/libvirt/hooks/qemu\""
    echo
    DIFF_RESULT=`diff /etc/libvirt/hooks/qemu /etc/libvirt/hooks/qemu.tmp`
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "$DIFF_RESULT"
        echo "Do you accept these changes?"
        echo "(Y/n)"
        read ACCEPT
        if [ "$ACCEPT" == "Y" ]; then
            sudo mv -f /etc/libvirt/hooks/qemu.tmp /etc/libvirt/hooks/qemu
        else
            echo "Aborting installation"
            sudo rm /etc/libvirt/hooks/qemu.tmp
            exit 1
        fi
    else
        echo "No changes needed! - will proceed...."
    fi
else
    sudo cat > /etc/libvirt/hooks/qemu << EOF
#!/bin/bash
date >> /var/log/qemu-x.log
echo "$@" >> /var/log/qemu-x.log
env >> /var/log/qemu-x.log
#<fuel_ci_pipeline>
# ---FUEL_CI_PIPELINE---: Do not touch! This configuration is automatically generated, changes will be over-written!
iptables -D FORWARD -o fuel1 -j REJECT --reject-with icmp-port-unreachable &>/dev/null
iptables -D FORWARD -o fuel2 -j REJECT --reject-with icmp-port-unreachable &>/dev/null
iptables -D FORWARD -o fuel3 -j REJECT --reject-with icmp-port-unreachable &>/dev/null
iptables -D FORWARD -o fuel4 -j REJECT --reject-with icmp-port-unreachable &>/dev/null
exit 0
#</fuel_ci_pipeline>
EOF

fi

sudo chmod 755 /etc/libvirt/hooks/qemu
echo "DONE - Adding needed qemu hooks to /etc/libvirt/hooks/qemu"
echo "=========================================================="
echo

echo
echo "Adding system configuration to /etc/sysctl"
if [ -e /etc/sysctl.conf ]; then
    sudo cp -f /etc/sysctl.conf /etc/sysctl.conf.bak
    sudo cat /etc/sysctl.conf | remove_fuel_insertions > /etc/sysctl.conf.tmp
    CONFLICT_REGEXP=("/*net.bridge.bridge-nf-call-ip6tables*/" "/*net.bridge.bridge-nf-call-iptables*/" "/*net.bridge.bridge-nf-call-arptables*/")
    cat /etc/sysctl.conf.tmp | check_conflict

    sudo cat >> /etc/sysctl.conf.tmp << EOF
#<fuel_ci_pipeline>
# ---FUEL_CI_PIPELINE---: Fix - Disable iptables traversal of virt interfaces needed for Fuel deploy
# ---FUEL_CI_PIPELINE---: Do not touch! This configuration is automatically generated, changes will be over-written!
net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
#</fuel_ci_pipeline>
EOF

    echo "/etc/sysctl.conf will be modified with new iptables traversal rules"
    echo "The original /etc/sysctl.conf file will be saved to /etc/sysctl.conf.bak"
    echo "WARNING: PLEASE REVIEW THE CHANGES CAREFULLY!"
    echo "Following changes will be made:"
    echo
    DIFF_RESULT=`diff /etc/sysctl.conf /etc/sysctl.conf.tmp`
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "$DIFF_RESULT"
        echo "Do you accept these changes?"
        echo "(Y/n)"
        read ACCEPT
        if [ "$ACCEPT" == "Y" ]; then
            sudo mv -f /etc/sysctl.conf.tmp /etc/sysctl.conf
            sudo chown root /etc/sysctl.conf
            sudo chgrp root /etc/sysctl.conf
            sudo chmod 755 /etc/sysctl.conf
            sudo sysctl -p
        else
            echo "Aborting installation"
            rm -f sysctl.conf.tmp
            exit 1
        fi
    else
        echo "No changes needed! - will proceed...."
    fi
else
    echo "/etc/sysctl.conf does not exist"
    echo "Aborting installation"
    exit 1
fi

echo "DONE - Adding system configuration to /etc/sysctl"
echo "================================================="
echo

echo
echo "Adding system configuration to /etc/default/docker (DOCKER_OPTS=.... --bip=172.42.0.1/16)"
if [ -e /etc/default/docker ]; then
    sudo cp -f /etc/default/docker /etc/default/docker.bak
    sudo cat /etc/default/docker | remove_fuel_insertions > /etc/default/docker.tmp
    CONFLICT_REGEXP=("/*--bip*/")
    cat /etc/sysctl.conf.tmp | check_conflict
    sudo cat >> /etc/default/docker.tmp << EOF
#<fuel_ci_pipeline>
#---FUEL_CI_PIPELINE---: Fix - Assign default IP adresses non overlapping with Fuel
# ---FUEL_CI_PIPELINE---: Do not touch! This configuration is automatically generated, changes will be over-written!
DOCKER_OPTS="\$DOCKER_OPTS --bip=172.42.0.1/16"
#</fuel_ci_pipeline>
EOF

    echo "/etc/default/docker will be modified with --bip (bridge ip) option"
    echo "Original /etc/default/docker file will be saved in /etc/default/docker.bak"
    echo "Following changes will be made:"
    echo
    DIFF_RESULT=`diff /etc/default/docker /etc/default/docker.tmp`
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "$DIFF_RESULT"
        echo "Do you accept these changes?"
        echo "(Y/n)"
        read ACCEPT
        if [ "$ACCEPT" == "Y" ]; then
            sudo mv -f /etc/default/docker.tmp /etc/default/docker
        else
            echo "Aborting installation"
            sudo rm -f /etc/default/docker.tmp
            exit 1
        fi
    else
        echo "No changes needed! - will proceed...."
    fi
else
    echo "/etc/default.docker does not exist"
    echo "Aborting installation"
    exit 1
fi
echo "DONE - Adding system configuration to /etc/default/docker (DOCKER_OPTS=.... --bip=172.42.0.1/16)"
echo "================================================================================================"
echo

echo
echo "Restarting docker service"
DOCKER_PROCS=`docker ps -q`
echo "#${DOCKER_PROCS}#"
# exit 1
if [ ! -z ${DOCKER_PROCS} ]; then
    echo "Docker instances are currently running, do you accept to restart docker anyway? (Y/n)"
    read ACCEPT
    if [ "$ACCEPT" != "Y" ]; then
        echo "You will need to manually restart docker at some conveniant time - before starting to use ci_pipeline.sh"
    else
        sudo service docker stop
        sudo ifconfig docker0 down &> /dev/null
        sudo brctl delbr docker0 &> /dev/null
        sudo service docker start
    fi
fi
sudo service docker stop
sudo ifconfig docker0 down &> /dev/null
sudo brctl delbr docker0 &> /dev/null
sudo service docker start

echo "Restarting libvirt service"
sudo service libvirt-bin restart

echo "===================================================="
echo "=========== INSTALLATION ALMOST READY =============="
echo "IMPORTANT:"
echo "Log-out and Log-in again....."
echo
echo "Now it is time to start playing with the CI engine:"
echo "The most basic task is to clone, build, deploy and verify a stable branch:"
echo "Try:"
echo "# sudo ci_pipeline.sh -b stable/arno"
echo
echo
if [ -z "$FORCEYES" ]; then
    echo "Do you want to browse the README file?"
    echo "(Y/n)?"
    read ACCEPT
    if [ "$ACCEPT" == "Y" ]; then
        more ${SCRIPT_PATH}/README.rst
    fi
fi
echo "===================================================="
