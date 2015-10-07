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

echo "===================================================="
echo "=========== INSTALLATION ALMOST READY =============="
echo "IMPORTANT:"
echo "Log-out and Log-in again....."
echo "Restart the docker and libvirt-bin deamons:"
echo "> service libvirt-bin restart"
echo "> service docker restart"
echo
echo "Now it is time to start playing with the CI engine:"
echo "The most basic task is to clone, build, deploy and verify a stable branch:"
echo "Try:"
echo "# ci_pipeline.sh -b stable/arno <Your Linux foundation account>"
echo
echo
if [ -z "$FORCEYES" ]; then
    echo "Do you want to browse the README file?"
    echo "(Y/N)?"
    read ACCEPT
    if [ "$ACCEPT" == "Y" ]; then
        more ${SCRIPT_PATH}/README.rst
    fi
fi
echo "===================================================="
