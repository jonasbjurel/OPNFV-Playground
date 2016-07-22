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
# Find potentially unresolvable system file conflicts
# defined by regexp string: $CONFLICT_EXPR
# If there is a conflict - terminate this install script!

for check_match in ${CONFLICT_EXPR}; do
    match=`sed -n ${check_match} $1`
    if [ ! -z "${match}" ]; then
        echo "Found an unresolvable conflict in file: ${INSTALL_FILE}:"
        echo "$match"
        echo "Aborting installation"
        exit 1
    fi
done
}

function install_file () {
    if [ -e ${INSTALL_FILE} ]; then
        sudo cp ${INSTALL_FILE} ${INSTALL_FILE}.bak
        sudo cat ${INSTALL_FILE} | remove_fuel_insertions > ${INSTALL_FILE}.tmp
        check_conflict ${INSTALL_FILE}.tmp
        sudo cat >> ${INSTALL_FILE}.tmp << EOF
$INSTALL_CONTENT
EOF

        echo "WARNING ${INSTALL_FILE} file already exists"
        echo "WARNING: Doing my best to edit the file accordingly - PLEASE REVIEW THE CHANGES CAREFULLY!"
        echo "Following changes will be done to \"${INSTALL_FILE}\""
        echo
        DIFF_RESULT=`diff ${INSTALL_FILE} ${INSTALL_FILE}.tmp`
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "$DIFF_RESULT"
            if [ -z "$FORCEYES" ]; then
                echo "Do you accept these changes?"
                echo "(Y/n)"
                read ACCEPT
            else
                ACCEPT="Y"
            fi
            if [ "$ACCEPT" == "Y" ]; then
                sudo mv -f ${INSTALL_FILE}.tmp ${INSTALL_FILE}
                sudo chmod 755 ${INSTALL_FILE}
            else
                echo "Aborting installation"
                sudo rm -f ${INSTALL_FILE}.tmp
                exit 1
            fi
        else
            echo "No changes needed! - will proceed...."
        fi
    else
        if [ $ALLOW_NO_EXISTS -eq 1 ]; then
              sudo cat > ${INSTALL_FILE} << EOF
$NO_EXIST_HEADER
EOF
            sudo cat >> ${INSTALL_FILE} << EOF
$INSTALL_CONTENT
EOF
            sudo chmod 755 ${INSTALL_FILE}
        else
            echo "${INSTALL_FILE} does not exist"
            echo "Aborting installation"
            exit 1
        fi
    fi
}


# Need to change umask to make sure that pip files are readable by all!
umask 0002

SCRIPT_PATH=`cd $(dirname $0); pwd`
USER=`/usr/bin/logname`

APT_PKG="git make curl libvirt-bin libpq-dev qemu-kvm qemu-system tightvncserver virt-manager sshpass fuseiso genisoimage blackbox xterm python-pip python-git python-dev python-oslo.config python-pip python-dev libffi-dev libxml2-dev libxslt1-dev libffi-dev libxml2-dev libxslt1-dev expect curl python-netaddr p7zip-full"
PIP_PKG="GitPython pyyaml netaddr paramiko lxml scp python-novaclient python-neutronclient python-glanceclient python-keystoneclient debtcollector netifaces enum"

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
echo
echo "=========================================================="
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
echo "Done - installing packages"
echo "=========================================================="
echo

echo
echo "=========================================================="
echo "Adding user ${USER} to needed services groups"
adduser ${USER} docker
adduser ${USER} libvirtd
echo "Done - Adding user ${USER} to needed services groups"
echo "=========================================================="
echo

echo
echo "=========================================================="
echo "Adding needed qemu hooks to /etc/libvirt/hooks/qemu"

INSTALL_FILE="/etc/libvirt/hooks/qemu"
INSTALL_CONTENT=$'#<fuel_ci_pipeline>
# ---FUEL_CI_PIPELINE---: Do not touch! This configuration is automatically generated, changes will be over-written!
iptables -D FORWARD -o fuel1 -j REJECT --reject-with icmp-port-unreachable &>/dev/null
iptables -D FORWARD -o fuel2 -j REJECT --reject-with icmp-port-unreachable &>/dev/null
iptables -D FORWARD -o fuel3 -j REJECT --reject-with icmp-port-unreachable &>/dev/null
iptables -D FORWARD -o fuel4 -j REJECT --reject-with icmp-port-unreachable &>/dev/null
exit 0
#</fuel_ci_pipeline>'
ALLOW_NO_EXISTS=1
NO_EXIST_HEADER=$'#!/bin/bash
date >> /var/log/qemu-x.log
echo "$@" >> /var/log/qemu-x.log
env >> /var/log/qemu-x.log'
# '/exit[:space:]0/p'
CONFLICT_EXPR=("/fuel1/p /fuel2/p /fuel3/p /fuel4/p")
install_file

echo "DONE - Adding needed qemu hooks to /etc/libvirt/hooks/qemu"
echo "=========================================================="
echo

echo
echo "=========================================================="
echo "Adding system configuration to /etc/sysctl"
INSTALL_FILE="/etc/sysctl.conf"
INSTALL_CONTENT=$'#<fuel_ci_pipeline>
# ---FUEL_CI_PIPELINE---: Fix - Disable iptables traversal of virt interfaces needed for Fuel deploy
# ---FUEL_CI_PIPELINE---: Do not touch! This configuration is automatically generated, changes will be over-written!
net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
#</fuel_ci_pipeline>'
ALLOW_NO_EXISTS=0
CONFLICT_EXPR=("/net.bridge.bridge-nf-call-ip6tables/p /net.bridge.bridge-nf-call-iptables/p /net.bridge.bridge-nf-call-arptables/p")
install_file
sudo sysctl -p &> /dev/null

echo "DONE - Adding system configuration to /etc/sysctl"
echo "================================================="
echo

echo
echo "================================================="
echo "Adding system configuration to /etc/default/docker (DOCKER_OPTS=.... --bip=172.42.0.1/16)"

INSTALL_FILE="/etc/default/docker"
INSTALL_CONTENT=$'#<fuel_ci_pipeline>
#---FUEL_CI_PIPELINE---: Fix - Assign default IP adresses non overlapping with Fuel
# ---FUEL_CI_PIPELINE---: Do not touch! This configuration is automatically generated, changes will be over-written!
DOCKER_OPTS="$DOCKER_OPTS --bip=172.42.0.1/16"
#</fuel_ci_pipeline>'
ALLOW_NO_EXISTS=0
CONFLICT_EXPR=("/--bip/p")
install_file

echo "DONE - Adding system configuration to /etc/default/docker (DOCKER_OPTS=.... --bip=172.42.0.1/16)"
echo "================================================="
echo

echo
echo "================================================="
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
echo "Done - Restarting docker service"
echo "================================================="
echo

echo
echo "================================================="
echo "Restarting libvirt service"
sudo service libvirt-bin restart
echo "Done - restarting libvirt service"
echo "================================================="
echo

echo "===================================================="
echo "=========== INSTALLATION ALMOST READY =============="
echo "IMPORTANT:"
echo "Before you can start using the CI Pipeline you need"
echo "add a password file with your sudo password:"
echo "$ touch ~/.cipassword"
echo "$ chmod 600 ~/.cipassword"
echo "$ echo <sudo pass> >> ~/.cipassword"
echo
echo "Log-out and Log-in again....."
echo
echo "Now it is time to start playing with the CI engine:"
echo "The most basic task is to clone, build, deploy and verify a stable branch:"
echo "Try:"
echo "$ ci_pipeline.sh -b stable/arno"
if [ -z "$FORCEYES" ]; then
    echo "Do you want to browse the README file?"
    echo "(Y/n)?"
    read ACCEPT
    if [ "$ACCEPT" == "Y" ]; then
        more ${SCRIPT_PATH}/README.rst
    fi
fi
echo "===================================================="
