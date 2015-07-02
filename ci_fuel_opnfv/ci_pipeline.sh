#!/bin/bash
set -e
##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# jonas.bjurel@ericsson.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

trap 'if [ RESULT != "SUCCESS" ]; then \ 
    echo "FAILED - see the log for details: ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log"; \
    usage; \
  fi; \
  put_result; \
  echo "Exiting ..."; \' EXIT

############################################################################
# BEGIN of usage description
#
usage ()
{
cat << EOF
$0 - Full Fuel@OPNFV CI Pipeline:
1) Clones and check-out Fuel@OPNFV from OPNFV Repos
2) Builds Fuel@OPNFV
3) Deploys a Fuel@OPNFV using nested KVM virtualization
4) Performs basic health tests
5) Future - Perfoms ordinary OPNFV CI pipeline functional tests
 
usage: $0 [-h] [-u local user] [-r local repo path] [-b branch ||-c change-set ] remote Linux foundation Gerrit user

-h Prints this message.
-u local linux user, only needed if the script is not placed under the home of the user that
   should be used for non priviledged bash actions.
-r Path to a local repository rather than using standard Fuel@OPNFV repo
-b Branch/commit Id to use.
-c Changeset to use

NOTE: This script must be run as root!

Examples:
sudo $0 -b stable/arno my_lf_user
sudo $0 -c refs/changes/41/941/1 my_lf_user
EOF
}
#
# END of usage description
############################################################################

############################################################################
# BEGIN of variable declartion
#
SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
HOME_SUFIX=${SCRIPT_PATH##/home/}
USER=${HOME_SUFIX%%/*}
BUILD_CACHE="${SCRIPT_PATH}/cache"
BUILD_CACHE_URI="file://${BUILD_CACHE}"
BUILD_ARTIFACT_STORE="artifact"
RESULT_FILE="result.log"
VERSION=`date -u +%F--%H.%M`
ISO="opnfv-${VERSION}.iso"
ISO_META="${ISO}.txt"
BRANCH="master"
CHANGE_SET=""
DEA="fuel/deploy/libvirt/conf/multinode/dea.yaml"
DHA="fuel/deploy/libvirt/conf/multinode/dha.yaml"
LOCAL_REPO=0
#
# END of usage description
############################################################################

############################################################################
# Start output of CI result 
#
function put_result {
    echo "Writing down ci-pipeline resuluts"
    su -c "echo 'Result: ${RESULT}     Build Id: ${VERSION}      Branch: ${BRANCH}     Commit ID: ${COMMIT_ID}     Total ci pipeline time: ${TOTAL_TIME} min    Total build time: ${BUILD_TIME} min     Total deployment time: ${DEPLOY_TIME} min' >> ${RESULT_FILE}" ${USER}
    su -c "echo 'Result: ${RESULT}     Build Id: ${VERSION}      Branch: ${BRANCH}     Commit ID: ${COMMIT_ID}     Total ci pipeline time: ${TOTAL_TIME} min    Total build time: ${BUILD_TIME} min     Total deployment time: ${DEPLOY_TIME} min' > ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/${RESULT_FILE}" ${USER}
}
#
# END of output
############################################################################

############################################################################
# Start of main
#
while getopts "u:b:c:r:h" OPTION
do
    case $OPTION in
	h)
	    usage
	    rc=0
	    exit $rc
	    ;;

	u)
	    USER=${OPTARG}
	    ;;

	b)
	    BRANCH=${OPTARG}
	    ;;

	c)
	    CHANGE_SET=${OPTARG}
	    ;;

	r)
	    REPO_PATH=${OPTARG}
	    LOCAL_REPO=1
	    ;;

	*)
	    echo "${OPTION} is not a valid argument"
	    exit 1
	    ;;
    esac
done

if [ `id -u` != 0 ]; then
  echo "This script must run as root!!!!"
  usage
  exit 1
fi

if [ -z $@ ]; then
  usage
  exit 1
fi 
LF_USER=$(echo $@ | cut -d ' ' -f ${OPTIND})
GIT_SRC="ssh://${LF_USER}@gerrit.opnfv.org:29418/genesis ${CHANGE_SET}"

echo "========== Running CI-pipeline with the following parameters =========="
echo "Local user: ${USER}"
echo "Gerrit user: ${LF_USER}"
echo "Branch: ${BRANCH}"
echo "Version: ${VERSION}"
echo "Cache URI: ${BUILD_CACHE_URI}"
echo "Build artifact output: ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}"

cd ${SCRIPT_PATH}
su -c "mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}" ${USER}
# Redirect stdout ( > ) into a named pipe ( >() ) running "tee"
exec > >(tee ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log)

# Without this, only stdout would be captured - i.e. your
# log file would not contain any error messages.
# SEE answer by Adam Spiers, which keeps STDERR a seperate stream -
# I did not want to steal from him by simply adding his answer to mine.
exec 2>&1

RESULT="Cloning failed"
if [ ${LOCAL_REPO} == 0 ]; then

  if [ -z $CHANGE_SET ]; then
    REPO_PATH="genesis"
  else
    REPO_PATH=${CHANGE_SET}
  fi
fi
BUILD_ARTIFACT_PATH="${REPO_PATH}/fuel/build_result"

if [ -${LOCAL_REPO} -eq 0 ]; then
  rm -rf ${REPO_PATH}
  echo "========== Cloning repository ${GIT_SRC} =========="
  su -c "git clone ${GIT_SRC}" ${USER}

  cd ${REPO_PATH}
  if [ -z $CHANGE_SET ]; then
    echo "========= Checking out branch/tag ${BRANCH} ========="
    su -c "git checkout ${BRANCH}" ${USER}
  else
    echo "========== Pulling the patch ${CHANGE_SET} =========="
    su -c "git pull ${GIT_SRC}" ${USER}
  fi
  COMMIT_ID=`git rev-parse HEAD`
fi
cd ${SCRIPT_PATH}

echo "========== Preparing build =========="
RESULT="Build failed"
time0=`date +%s`
su -c "mkdir -p ${BUILD_CACHE}" ${USER}
su -c "mkdir -p ${SCRIPT_PATH}/${BUILD_ARTIFACT_PATH}" ${USER}
cd ${SCRIPT_PATH}/${REPO_PATH}/fuel/ci

echo "========== Building  =========="
# NEED TO FIX "build.sh" such as it can be ran from arbitrary parent path
su -c "./build.sh -v ${VERSION} -c ${BUILD_CACHE_URI} ${SCRIPT_PATH}/${BUILD_ARTIFACT_PATH}" ${USER}
cd ${SCRIPT_PATH}
su -c "cp ${SCRIPT_PATH}/${BUILD_ARTIFACT_PATH}/${ISO} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/." ${USER}
su -c "cp ${SCRIPT_PATH}/${BUILD_ARTIFACT_PATH}/${ISO_META} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/." ${USER}
time1=`date +%s`
BUILD_TIME=$[(time1-time0)/60]
echo "========== Build took ${BUILD_TIME} minutes =========="

time0=`date +%s`
echo "========== Deploying =========="
RESULT="Deploy failed"
cd ${SCRIPT_PATH}
python ./${REPO_PATH}/fuel/deploy/deploy.py ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/${ISO} ${SCRIPT_PATH}/${REPO_PATH}/${DEA} ${SCRIPT_PATH}/${REPO_PATH}/${DHA}
time1=`date +%s`
DEPLOY_TIME=$[(time1-time0)/60]
echo "========== Deploy took ${DEPLOY_TIME} minutes =========="

time0=`date +%s`
echo "========== Running func test =========="
RESULT="OPNV Functional test suite failed"
#
# Place holder for functest code
#
time1=`date +%s`
TEST_TIME=$[(time1-time0)/60]
echo "========== func test took ${TEST_TIME} minutes =========="
RESULT="SUCCESS"

TOTAL_TIME=$[BUILD_TIME+DEPLOY_TIME+TEST_TIME]

echo "========================= Total Sucess  ========================="
echo "==================== Total CI time: ${TOTAL_TIME} min ====================="
echo "============ Open OPNVF resources as indicated below: ==========="
echo "================ Fuel GUI: http://10.20.0.2:8000 ================"
echo "======== OpenStack Horizon GUI: http://10.20.0.3:XXXXX =========="
echo "=========== OpenDaylight GUI: http://10.20.0.3:XXXXX ============"

exit 0
#
# END of main
############################################################################
