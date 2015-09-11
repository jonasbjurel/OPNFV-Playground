#!/bin/bash
##############################################################################
# Copyright (c) 2015 Jonas Bjurel and others.
# jonasbjurel@hotmail.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Need to change umask to make sure that php files are readable by all!
umask 0002

SCRIPT_PATH=`cd $(dirname $0); pwd`
USER=`/usr/bin/logname`

APT_PKG="git python-pip python-libvirt python-libxml2 novnc supervisor nginx php5 php5-dev php-pear libyaml-dev"

PHP_PKG="yaml-0.6.3"

if [ `id -u` != 0 ]; then
  echo "This script must run as root!!!!"
  echo "I.e. sudo $0"
  exit 1
fi

if [[ -z `uname -a | grep Ubuntu` ]]; then
   echo "You are Not running Ubuntu - for the time being you set-up is unsuported"
   exit 1
fi

if [[ -z `lsb_release -a | grep Release | grep 14.04` ]]; then
   echo "You are running Ubuntu - but not currently supported version: 14.04"
   echo "Compatibility cannot be ensured - but you can try installing dependencies manually...:"
    echo "These are the 14.04 dependencies/packages we reccomend:"
    echo "APT pakages:"
    echo "$APT_PKG"
    echo
    echo "PHP packages"
    echo "$PHP_PKG"
    echo
    echo "Add your user to the www-data group:"
    echo "# sudo adduser <your UID> www-data"
    echo "Add the www-data user to the libvirtd group:"
    echo "# sudo adduser www-data libvirtd"
    echo
    echo "Log-out followed by a Log-in"
    echo
    echo "Restart the apache2 deamon:"
    echo "# sudo service apache2 restart"
    echo
    echo "From this point on - see README.rst"
    echo "Good luck!"
    exit 1
fi

echo "This script will install all needed dependencies for the fuel@OPNFV simplified CI engine......"
echo
echo "Following packages will be installed:"
echo "$APT_PKG $PHP_PKG"
echo
echo "DO YOU AGREE?"
echo "(Y/n)"
read ACCEPT
if [ "$ACCEPT" != "Y" ]; then
    echo "Fine you may still try to install needed packages manually, these are the packages we reccomend:"
    echo "APT pakages:"
    echo "$APT_PKG"
    echo
    echo "PHP packages"
    echo "$PHP_PKG"
    echo
    echo "Add your user to the www-data group:"
    echo "# sudo adduser <your UID> www-data"
    echo "Add the www-data user to the libvirtd group:"
    echo "# sudo adduser www-data libvirtd"
    echo
    echo "Log-out followed by a Log-in"
    echo
    echo "Restart the apache2 deamon:"
    echo "# sudo service apache2 restart"
    echo
    echo "From this point on - see README.rst"
    echo "Good luck!"
    exit 1
fi

sudo apt-get update
sudo apt-get install $APT_PKG
sudo pecl install $PHP_PKG

sudo adduser -G www-data ${USER}
sudo adduser -G libvirtd www-data

sudo service apache2 restart

echo "edit the /etc/apache2/conf.d/yaml.ini file by:"
echo "$ cd /etc/apache2/conf.d"
echo "$ sudo vi yaml.ini"
echo "add the following line:  extension=yaml.so"
