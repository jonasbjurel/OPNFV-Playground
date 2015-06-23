#!/bin/bash
set -e
##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# stefan.k.berg@ericsson.com
# jonas.bjurel@ericsson.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

trap 'put_result; \
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
4) Performs basic healt tests

usage: $0 [-u local user] [-b branch] remote Linux foundation Gerrit user

Examples:
EOF
}
#
# END of usage description
############################################################################

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
HOME_SUFIX=${SCRIPT_PATH##/home/}
USER=${HOME_SUFIX%%/*}
BRANCH="master"
BUILD_CACHE="${SCRIPT_PATH}/cache"
BUILD_ARTIFACT_PATH="genesis/fuel/build_result"
BUILD_ARTIFACT_STORE="artifact"
BUILD_CACHE_URI="file://${BUILD_CACHE}"
VERSION=`date -u +%F--%H.%M`
ISO="opnfv-${VERSION}.iso"
ISO_META="${ISO}.txt"
VIRT_STORAGE_PATH="/root/virtstorage"
DEA="./deploy_config/libvirt/conf/dea.yaml"
DHA="./deploy_config/libvirt/conf/dha.yaml"

function put_result {
    su -c "echo 'Result: ${RESULT}     Build Id: ${VERSION}      Branch: ${BRANCH}     Commit ID: ${COMMIT_ID}     Total ci pipeline time:     Total build time:     Total deployment time:' >> ${RESULT_FILE}" ${USER}
    su -c "echo 'Result: ${RESULT}     Build Id: ${VERSION}      Branch: ${BRANCH}     Commit ID: ${COMMIT_ID}     Total ci pipeline time:     Total build time:     Total deployment time:' > ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci_result.log" ${USER}
}

while getopts "u:b:h" OPTION
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

	*)
	    echo "${OPTION} is not a valid argument"
	    exit 1
	    ;;
    esac
done

if [ id -u != 0 ]; then
  echo "This script must run as root!!!!"
  usage
  exit 1
fi

if [ -z $@ ]; then
  usage
  exit 1
fi
LF_USER=$(echo $@ | cut -d ' ' -f ${OPTIND})
GIT_SRC="ssh://${LF_USER}@gerrit.opnfv.org:29418/genesis"

echo "========== Running CI-pipeline with the following parameters ==========="
echo "Local user: ${USER}"
echo "Gerrit user: ${LF_USER}"
echo "Branch: ${BRANCH}"
echo "Version: ${VERSION}"
echo "Cache URI: ${BUILD_CACHE_URI}"
echo "Build artifact output: ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}"

cd ${SCRIPT_PATH}
echo "SCRIPT_PATH: ${SCRIPT_PATH}"
su -c "mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}" ${USER}
# Redirect stdout ( > ) into a named pipe ( >() ) running "tee"
#exec > >(tee ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log)

# Without this, only stdout would be captured - i.e. your
# log file would not contain any error messages.
# SEE answer by Adam Spiers, which keeps STDERR a seperate stream -
# I did not want to steal from him by simply adding his answer to mine.
#exec 2>&1

#script -a ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/output.log
RESULT="Cloning failed"
echo "========= Cloning repository ========="
rm -rf genesis
su -c "git clone ${GIT_SRC}" ${USER}
cd genesis
echo "========= Checking out branch/tag ${BRANCH} ========="
su -c "git checkout ${BRANCH}" ${UABJONB}
COMMIT_ID=`git rev-parse HEAD`
cd ${SCRIPT_PATH}

echo "========= Preparing build ========="
RESULT="Build failed"
su -c "mkdir -p ${BUILD_CACHE}" ${USER}

su -c "mkdir -p ${SCRIPT_PATH}/${BUILD_ARTIFACT_PATH}" ${USER}
cd ${SCRIPT_PATH}/genesis/fuel/ci

# NEED TO FIX "build.sh" such as it can be ran from arbitrary parent path

echo "========== Building  ==========="
su -c "./build.sh -v ${VERSION} -c ${BUILD_CACHE_URI} ${SCRIPT_PATH}/${BUILD_ARTIFACT_PATH}" ${USER}
cd ${SCRIPT_PATH}
su -c "cp ${SCRIPT_PATH}/${BUILD_ARTIFACT_PATH}/${ISO} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/." ${USER}
su -c "cp ${SCRIPT_PATH}/${BUILD_ARTIFACT_PATH}/${ISO_META} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/." ${USER}

echo "========== Deploying =========="
RESULT="Deploy failed"
#Fix script so that it can be referenced from anywhere
cd deploy_config/libvirt/
./setup_example_vms.sh ${VIRT_STORAGE_PATH}
cd ${SCRIPT_PATH}
./genesis/fuel/prototypes/auto-deploy/deploy/deploy.sh ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/${ISO} ${DEA} ${DHA}
RESULT="Success"

exit 0
