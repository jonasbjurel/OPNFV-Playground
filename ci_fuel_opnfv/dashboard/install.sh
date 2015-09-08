#!/bin/bash
##############################################################################
# Copyright (c) 2015 Jonas Bjurel and others.
# jonasbjurel@hotmail.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# NEEDS MORE WORK!, NOT TESTED AT ALL!
sudo apt-get install git python-pip python-libvirt python-libxml2 novnc supervisor nginx php5 php5-dev php-pear libyaml-dev

sudo pecl install yaml-0.6.3

sudo adduser www-data libvirtd
sudo adduser uabjonb www-data

echo "edit the /etc/apache2/conf.d/yaml.ini file by:"
echo "$ cd /etc/apache2/conf.d"
echo "$ sudo vi yaml.ini"
echo "add the following line:  extension=yaml.so"

echo "restar the Apache 2 server:"
echo "$ sudo apache2ctl restart"
