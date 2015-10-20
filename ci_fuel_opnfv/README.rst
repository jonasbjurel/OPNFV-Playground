.. ##############################################################################
.. # Copyright (c) 2015 Ericsson AB and others.
.. # jonas.bjurel@ericsson.com
.. # All rights reserved. This program and the accompanying materials
.. # are made available under the terms of the Apache License, Version 2.0
.. # which accompanies this distribution, and is available at
.. # http://www.apache.org/licenses/LICENSE-2.0
.. ##############################################################################

INTRODUCTION
============
This is a lightweight developer's CI-engine (build/deploy/verify-engine) for
Fuel@OPNFV.

REQUIREMENTS
============
The pipeline works on a Ubuntu 14.04 machine with at least 16 hyperthreads,
16 GByte of RAM and 500 GByte disk.

INSTALLING THE PIPELINE
=======================
First, install the CI-engine including all needed dependencies by typing:

$ sudo install.sh

Before you can start using the CI Pipeline you need to add a password file with your sudo password:

$ touch ~/.cipassword

$ chmod 600 ~/.cipassword

$ echo <sudo pass> >> ~/.cipassword

And finally Log-out and Log-in again.....

RUNNING THE PIPELINE
====================
Then run the CI pipeline:

$ ./ci_pipeline.sh -b <branch>

Where branch currently can be any of:

- master (The Fuel@OPNFV master branch)
- stable/arno (The Fuel@OPNFV Arno stable branch)
- arno.2015.1.0 (The Arno SR0 release)
- arno.2015.2.0 (The Arno SR1 release)
- An arbitrary changeset (e.g. refs/changes/33/2633/7)

The pipeline will perform the following tasks:

- Build fuel and store the .iso artifact in the artifact library.
- Deploy the results on KVM
- Run function test suites

For more options/help type:

$ ./ci_pipeline.sh -h

FILES
=====

- ./README.rst
  This file
- ./PROJECT.rst
  Holds project information
- /var/run/fuel/ci-status
  Holds the current status of the CI engine
- ./result.log
  Holds a log of all previous ci results
- ./artifact/<branch>/<bild_id>/
  Contains the built .iso file, meta-data, ci.log containing the log produced by the CI run.
- ./artifact/<branch>/<bild_id>/test_result/
  Contains all the test results from the CI run.
- ~/.cipassword
  Must be created and contain the sudo password.
  Note that the file permissions must be extremely restrive, I.e. 600

MORE READING
============
You can find more reading at: https://github.com/jonasbjurel/OPNFV-Playground/wiki/fuel_opnfv_sandbox
