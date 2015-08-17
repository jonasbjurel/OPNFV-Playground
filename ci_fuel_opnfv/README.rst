##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# jonas.bjurel@ericsson.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

This is a lightweight CI-engine (build/deploy/verify-engin) for Fuel@OPNFV.
It woeks on a Ubuntu 14.04 server with at least 16 hyperthreads, 16 GByte of RAM and 500 GByte disk.

First ensure all dependencies are installed by typing:
# sudo install.sh

Then run ci_pipeline.sh as root
# sudo ./ci_pipeline.sh -b <branch> <Linuxfoundation_user>
Where branch currently can be any of:
- master (The Fuel@OPNFV master branch)
- stable/arno (The Fuel@OPNFV Arno stable branch)
- arno.2015.1.0 (The Arno SR0 release)

This script will:
- Build fuel and store the .iso artifact in the artifact library.
- Deploy the results on KVM
- Run function test suites

For options/help type:
# sudo ./ci_pipeline.sh -h

Files:
./README.rst
  This file

./PROJECT.rst
  Holds project information

./ci-status
  Holds the current status of the CI engine

./xxxx.log
  Holds the log of all previous ci results

./artifact/<branch>/<bild_id>/
  Contains the built .iso file, meta-data as well as the ci-log produced by the ci run.

./artifact/<branch>/<bild_id>/test-result
  Containbs the ci test-results


