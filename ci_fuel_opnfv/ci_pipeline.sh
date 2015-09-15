#!/bin/bash
set -e
##############################################################################
# Copyright (c) 2015 Jonas Bjurel and others.
# jonasbjurel@hotmail.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

############################################################################
# BEGIN of Exit handlers
#

do_exit () {
    if [ $? -eq 130 ]; then
        RESULT="INFO CI-pipeline interrupted"
    fi
    if [ ${rc} -ne 0 ]; then
        if [ -d  ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION} ]; then 
            echo "FAILED - see the log for details: ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log"
        else
            echo "FAILED - see the log for details: ${RESULT_FILE}"
        fi
    fi
    TOTAL_TIME=$[BUILD_TIME+DEPLOY_TIME+TEST_TIME];
    put_result;
    if [ -e ${SCRIPT_PATH}/${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log ]; then
        chown ${USER} ${SCRIPT_PATH}/${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log
        chgrp rnd ${SCRIPT_PATH}/${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log
    fi
    echo "result: $rc"
    # Note exit code 100 is a special code for no clean-up,
    # eg used when another instance is already running
    if [ $rc -ne 100 ]; then
        cd $SCRIPT_PATH
        clean;
        STATUS="IDLE"
        put_status
    fi

     if [ ! -z ${LOGPID} ]; then 
         kill $LOGPID
     fi
     if [ ! -z ${TEMPEST_LOGPID} ]; then 
         kill ${TEMPEST_LOGPID}
     fi
     if [ ! -z ${VPING_LOGPID} ]; then 
         kill ${VPING_LOGPID}
     fi

     echo "Exiting ..."
}

#
# End of Exit handlers
############################################################################


############################################################################
# BEGIN of usage description
#
usage ()
{
    PUSH_PATH=`pwd`
    cat << EOF
$0 - Simple Fuel@OPNFV CI Pipeline:
1) Clones and check-out Fuel@OPNFV from OPNFV Repos"
2) Builds Fuel@OPNFV
3) Deploys a Fuel@OPNFV using local nested KVM virtualization
4) Performs basic health tests
5) Perfoms ordinary OPNFV CI pipeline functional tests

usage: $0 [-h] [-a deploy_config] [-u local user] [-r local repo path] [-b branch | -c change-set ] [-BDT] [-t] [-i Iso image] [-p | -P] [-I] [Linux foundation user]

-h Prints this message.
-a Deploys the named config from config/<Fuel version>/deploy_config. Defaults to "default_no_ha", or the
   content of the environment variable \$DEPLOYTGT.
-u local linux user, only needed if the script is not placed under the home of the user that
   should be used for non priviledged bash actions.
-r Path to a local repository rather than using standard Fuel@OPNFV repo, this option can not be combined with the -c, -B, or -I options.
-b Branch/commit Id to use, this option can not be combined with -B
-c Changeset to use, this option requires a "Linux foundation user" and can not be combined with the -B or -r options.
-I Invalidate cache, invalidates local cache and builds all from upstream, cannot be accompanioned with the -B option.
-B Skip build stage, this option cannot be combined with the -r, -b, -c or -D options.
-D Skip deploy stage, this option must either be accompanioned with the -i <iso> option or else it can not be accompanioned with the -B option
-T Skip functest stage
-t Only perform smoke test, this option can not be accompanioned with the -T option,
-i iso image (needed if build stage is skipped and no previous deployment exists), this option asumes the -B option.
-p Post run - Purge all including running deployment - but excluding cache
-P Post run - purge ALL

Examples:
$0 -b master -  (Clones, Builds, Deploys & Tests out of the master branch)
$0 -b stable/arno  -  (Clones, Builds, Deploys & Tests out of stable/arno branch)
$0 -c refs/changes/41/941/1 <my_lf_user> - (Clones, Builds, Deploys & Tests out of the non merged patch "/41/941/1")
$0 -b master -DT - (Only builds master)
$0 -T - (Only tests an existing seployment)
$0 -BDT -P (Purges all except the installation)

NOTE: THIS SCRIPT MAY NOT BE RAN AS ROOT
EOF
    cd $PUSH_PATH
}
#
# END of usage description
############################################################################

############################################################################
# BEGIN of .yaml parser
#
function parse_yaml() {
    PUSH_PATH=`pwd`
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
    cd $PUSH_PATH
}
#
# END of .yaml parser
############################################################################




############################################################################
# BEGIN of fetch_config
#
function fetch_config() {
    PUSH_PATH=`pwd`
    # Parse config yaml files
    eval $(parse_yaml ${DEA} "dea_")
    eval $(parse_yaml ${DHA} "dha_")

    # Assign config variables
    FUEL_IP=$dea_fuel_ADMIN_NETWORK_ipaddress
    FUEL_GUI_USR=$dea_fuel_FUEL_ACCESS_user
    FUEL_GUI_PASSWD=$dea_fuel_FUEL_ACCESS_password
    FUEL_SSH_USR=$dha_nodes_username
    FUEL_SSH_PASSWD=$dha_nodes_password

    # Todo: yaml parser need to improve such that it can parse arrays and catch OS_IP below
    OS_IP="172.16.0.2"
    ADMIN_OS_USR="admin"
    ADMIN_OS_PASSWD=$dea_settings_editable_access_password_value

    cd $PUSH_PATH
}

#
# END of fetch_config
############################################################################

############################################################################
# Start output of CI result
#
function put_result {
    PUSH_PATH=`pwd`
    LOG_MSG="Result: ${RESULT} | Build Id: ${VERSION} | Branch: ${BRANCH} | Commit ID: ${COMMIT_ID} | Total ci pipeline time: ${TOTAL_TIME} min | Total build time: ${BUILD_TIME} min | Total deployment time: ${DEPLOY_TIME} | Total functest time: ${TEST_TIME}"
    echo $LOG_MSG >> ${SCRIPT_PATH}/${RESULT_FILE}
    if [ -d  ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION} ]; then
        echo $LOG_MSG > ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/${RESULT_FILE}
    fi
    cd $PUSH_PATH
}
#
# END of output
############################################################################

############################################################################
# Start report CI status
#
function put_status {
    PUSH_PATH=`pwd`
    sudo mkdir -p ${STATUS_FILE_PATH}
    if [ ${STATUS} == "IDLE" ]; then
        sudo sh -c "echo \"${STATUS} | $('date')\" > ${STATUS_FILE_PATH}/ci-status"
    else
        sudo sh -c "sudo echo \"${STATUS} | $('date') | ${BRANCH} | ${COMMIT_ID} | ${VERSION}\" > ${STATUS_FILE_PATH}/ci-status"
    fi
    cd $PUSH_PATH
}

#
# END report CI status
############################################################################

############################################################################
# Evaluate parameters
#
function eval_params {

    if [ $CHANGE_SET_PROVIDED -eq 1 ]; then
        if [ $LOCAL_PATH_PROVIDED -eq 1 ]; then
            echo "Can not operate on the change-set: -c $CHANGE_SET while working from local path -r $REPO_PATH"
            usage
            RESULT="ERROR - Faulty script input parameters"
            exit 1
        fi

        if [ $BUILD -eq 0 ]; then
            echo Im here
            echo "Providing a changeset: -c $CHANGE_SET while providing the -B option (skip build) does not make sense"
            usage
            RESULT="ERROR - Faulty script input parameters"
            exit 1
        fi

        if [[ -z $LF_USER ]]; then
            echo "LF user provided needs to be provided in order to operate on a change-set"
            usage
            RESULT="ERROR - No LF user provided"
            exit 1$CHANGE_SET_PROVIDED -eq 0
        fi
    fi

    if [ $BUILD -eq 1 ]; then
        if [ $DEPLOY -eq 0 ] && [ $TEST -eq 1 ]; then
            echo "You need to deploy a build if you want to test it, option -D alone does not make sense (-DT could make sense if you only want to build, or -BD if you want to test an existing deployment)"
            usage
            RESULT="ERROR - Faulty script input parameters"
            exit 1
        fi

        if [ $LOCAL_ISO_PROVIDED -eq 1 ]; then
            echo "Since build has not been disabled (-B) it makes no sense to provide a local iso (-i $LOCAL_ISO)"
            usage
            RESULT="ERROR - Faulty script input parameters"
            exit 1
        fi
    fi

    if [ $BUILD -eq 0 ]; then
        if [ $CHANGE_SET_PROVIDED -eq 1 ] || [ $LOCAL_REPO_PROVIDED -eq 1 ] || [ $LOCAL_PATH_PROVIDED -eq 1 ] || \
            [ $INVALIDATE_CACHE -eq 1 ]; then
            echo "As build is disabled (-B), it does not make sense to specify either of the following options: a change-set (-c ...), a local repository (-r ...), or to invalidate the build cache (-I)"
            usage
            RESULT="ERROR - Faulty script input parameters"
            exit 1
        fi
    fi

    if [ $DEPLOY -eq 1 ]; then
        if [ $BUILD -eq 0 ] && [ $LOCAL_ISO_PROVIDED -eq 0 ]; then
            echo "No ISO provided (by -i <iso>) while build is disabled (-B). Nothing to deploy!!!!!"
            usage
            RESULT="ERROR - Faulty script input parameters"
            exit 1
        fi
    fi

    if [ $DEPLOY -eq 0 ]; then
        if [ $LOCAL_ISO_PROVIDED -eq 1 ]; then
            echo "Since deploy is disabled it makes no sense to provide a local iso (-i $LOCAL_ISO)"
            usage
            RESULT="ERROR - Faulty script input parameters"
            exit 1
        fi
    fi

    if [ $TEST -eq 1 ]; then
        if [ $DEPLOY -eq 0 ]; then
            echo "Since nothing will be deployed (-D) an existing deployment will be tested provided that one exists"
        fi
    fi

    if [[ -z $LF_USER ]]; then
        echo "Since no LinuxFoundation user is provided, the repositories will be pulled using https:// methods (as aposed to git:// or ssh://)"
    fi

}

#
# END Evaluate parameters
############################################################################

############################################################################
# Check CI-pipeline availability
#
function check_avail {
if [[ -e ${STATUS_FILE_PATH}/ci-status ]] && [[ -z `cat ${STATUS_FILE_PATH}/ci-status | grep IDLE` ]]; then
    echo "CI-Pipline busy!"
    RESULT="INFO - CI-pipeline busy"
    rc=100
    exit 100
fi
}

#
# END Check CI-pipeline availability
############################################################################

############################################################################
# BEGIN of clone repo
#

function clone_repo {
    PUSH_PATH=`pwd`
    RESULT="ERROR - GIT Cloning failed"
    STATUS="CLONING"
    put_status

    cd ${SCRIPT_PATH}
    if [ ${LOCAL_PATH_PROVIDED} -eq 0 ]; then
        if [ $CHANGE_SET_PROVIDED -eq 0 ]; then
            REPO_PATH=${SCRIPT_PATH}/"genesis"
        else
            REPO_PATH=${SCRIPT_PATH}/${CHANGE_SET}
        fi

        rm -rf ${REPO_PATH}
        if [ $LOCAL_REPO_PROVIDED -eq 1 ]; then
            echo
            echo "========== Cloning local ${LOCAL_REPO} =========="
            git clone ${LOCAL_REPO}
        else
            if [[ -z $LF_USER ]]; then
                echo
                echo "========== Cloning repository ${GIT_HTTPS_SRC} =========="
                git clone ${GIT_HTTPS_SRC}
            else
                echo
                echo "========== Cloning repository ${GIT_SRC} =========="
                git clone ${GIT_SRC}
            fi
        fi

        if [ $CHANGE_SET_PROVIDED -eq 0 ]; then
            echo "========= Checking out branch/tag ${BRANCH} ========="
            pushd ${REPO_PATH}
            git checkout ${BRANCH}
        else
            echo "========== Pulling the patch ${CHANGE_SET} =========="
            pushd ${REPO_PATH}
            git pull ${GIT_SRC}
        fi
        COMMIT_ID=`git rev-parse HEAD`
        popd
    else
        # Local path provided
        REPO_PATH=${LOCAL_PATH}
        COMMIT_ID="NIL"
    fi

    BUILD_ARTIFACT_PATH="${REPO_PATH}/fuel/build_result"
    echo "Commit ID is ${COMMIT_ID}"

    cd $PUSH_PATH
}

#
# END of clone repo
############################################################################

############################################################################
# BEGIN of build
#

function build {
    PUSH_PATH=`pwd`
    echo "========== Preparing build =========="
    RESULT="ERROR - Build failed"
    STATUS="BUILDING"
    put_status

    cd ${SCRIPT_PATH}
    mkdir -p ${BUILD_CACHE}
    mkdir -p ${BUILD_ARTIFACT_PATH}

    echo
    echo "========== Building  =========="
    # <FIX> NEED TO FIX "build.sh" such as it can be ran from arbitrary parent path

    if [ $INVALIDATE_CACHE -ne 1 ]; then
        pushd ${REPO_PATH}/fuel/ci
        echo ./build.sh -v ${VERSION} -c ${BUILD_CACHE_URI} ${BUILD_ARTIFACT_PATH}
        ./build.sh -v ${VERSION} -c ${BUILD_CACHE_URI} ${BUILD_ARTIFACT_PATH}
        popd
    else
        pushd ${REPO_PATH}/fuel/ci
        echo ./build.sh -v ${VERSION} -c ${BUILD_CACHE_URI} -f P ${BUILD_ARTIFACT_PATH}
        ./build.sh -v ${VERSION} -c ${BUILD_CACHE_URI} -f P ${BUILD_ARTIFACT_PATH}
        popd
    fi

    echo mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}
    mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}
    echo cp ${BUILD_ARTIFACT_PATH}/${ISO} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}
    cp ${BUILD_ARTIFACT_PATH}/${ISO} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}
    echo cp ${BUILD_ARTIFACT_PATH}/${ISO_META} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}
    cp ${BUILD_ARTIFACT_PATH}/${ISO_META} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}

    cd $PUSH_PATH
}

#
# END of build
############################################################################

############################################################################
# BEGIN of deploy
#

function deploy {
    local ISOFILE


    PUSH_PATH=`pwd`
    echo
    echo "========== Deploying =========="
    RESULT="ERROR - Deploy failed"
    STATUS="DEPLOYING"
    put_status

    echo "Starting virtualization manager GUI"

    # <FIX> Such that virt-manager spawns
    virt-manager &
    echo cd ${SCRIPT_PATH}
    cd ${SCRIPT_PATH}
    echo "Repo path is ${REPO_PATH}"

    if [ $BUILD -eq 1 ]; then
       ISOFILE=${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/${ISO}
    else
       ISOFILE=${LOCAL_ISO}
    fi


    VERSION=$(7z x -so $ISOFILE version.yaml 2>/dev/null \
        | grep release | sed 's/.*: "\(...\).*/\1/')

    if [ -n "${VERSION}" ]; then
        echo "Fuel version is in ISO is ${VERSION}"
    else
        echo "Error: Could not retrieve Fuel version from $ISOFILE"
        exit 1
    fi

    if [ -d "${SCRIPT_PATH}/config/${VERSION}"  ]; then
        DEA=${SCRIPT_PATH}/config/${VERSION}/${DEPLOY_CONFIG}/dea.yaml
        DHA=${SCRIPT_PATH}/config/${VERSION}/${DEPLOY_CONFIG}/dha.yaml
        if [ ! -f $DEA ]; then
            echo "Could not find DEA file $DEA"
            exit 1
        fi

        if [ ! -f $DHA ]; then
            echo "Could not find DHA file $DHA"
            exit 1
        fi

        # Handle different deployer versions
        case "${VERSION}" in
            "6.0")
                echo sudo python ${REPO_PATH}/fuel/deploy/deploy.py ${ISOFILE} ${DEA} ${DHA}
                sudo python ${REPO_PATH}/fuel/deploy/deploy.py ${ISOFILE} ${DEA} ${DHA}
                ;;
            *)
                echo sudo python ${REPO_PATH}/fuel/deploy/deploy.py -iso ${ISOFILE} -dea ${DEA} -dha ${DHA}
                sudo python ${REPO_PATH}/fuel/deploy/deploy.py -iso ${ISOFILE} -dea ${DEA} -dha ${DHA}
                ;;
        esac
    else
        echo "Error: No deploy config directory for ${VERSION}"
        exit 1
    fi
    cd $PUSH_PATH
}

#
# END of deploy
############################################################################

############################################################################
# BEGIN of func test
#

function func_test {
    PUSH_PATH=`pwd`
    cd ${SCRIPT_PATH}
    echo
    echo "========== Preparing func test =========="
    RESULT="ERROR - OPNV Functional test setup failed"
    STATUS="FUNCTEST_PREP"
    put_status
    # Remove any residual of functest environment
    rm -rf functest
    rm -rf ${HOME}/functest
    # Create result directory
    mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result


    # Get stack configuration and credentials
    echo "Get stack config...."
    fetch_config
    cd ${SCRIPT_PATH}/credentials
    echo ./pull-cred ${FUEL_IP} ${FUEL_SSH_PASSWD}
    ./pull-cred ${FUEL_IP} ${FUEL_SSH_PASSWD}

    # modify openrc with public AUTH access end point
    if [ ! -e openrc ]; then
        echo "Fetching openrc failed"
        exit 1
    fi
    mv openrc openrc.orig
    EXT_AUTH_URL="'http:\/\/${OS_IP}:5000\/v2.0\/'"
    OS_AUTH_LINE=`grep -n OS_AUTH_URL openrc.orig | cut -d \: -f 1`

    # <FIX> Workaround due to that I cant get su working - quote escape issue
    #su -c "cat openrc.orig | sed "'${OS_AUTH_LINE}'s/.*/'"export OS_AUTH_URL=${EXT_AUTH_URL}"'/' > openrc" ${USER}
    cat openrc.orig | sed ''${OS_AUTH_LINE}'s/.*/'"export OS_AUTH_URL=${EXT_AUTH_URL}"'/' > openrc
    chown $USER openrc
    chgrp rnd openrc

    # Clone the functest repo and configure it
    echo "Cloning functest...."
    cd ${SCRIPT_PATH}
    git clone https://git.opnfv.org/functest
    echo "Copying configuration...."
    cp config/config_functest.yaml functest/testcases/.

    # Install functest
    echo "Installing functest...."
    # <FIX> Temporary worakround since the install doesnt run withn su
    #su -c "source credentials/openrc && python functest/testcases/config_functest.py -d functest/ start" ${USER}

    source credentials/openrc && python functest/testcases/config_functest.py -d functest/ start

    echo
    echo "========== Running func tests =========="

    echo
    echo "========== Runing Tempest smoke test =========="
    RESULT="ERROR OPNV Functional Tempest test failed"
    STATUS="FUNCTEST_TEMPEST"
    put_status

    # Redirect stdout to the log-file
    mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/tempest
    touch ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/tempest/result.log > /dev/null
    tail -n 0 -f ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log > ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/tempest/result.log &
    sleep 0.3
    TEMPEST_LOGPID=$!

    # <FIX> Tempest cant run as other than root - root-cause is probably that func test cant install with su ".." $USER!
    #su -c "source credentials/openrc && rally verify start smoke" ${USER}
    source credentials/openrc && rally verify start smoke

    kill ${TEMPEST_LOGPID}

    if [ $SMOKE -eq 0 ]; then
        echo
        echo "========== Running Rally tests =========="
        RESULT="ERROR - OPNV Functional Rally test failed"
        STATUS="FUNCTEST_RALLY"
        put_status

        mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/rally
        # <FIX> Rally cant run as other than root - root-cause is probably that func test cant install with su ".." 
        # <FIX> Until rally runs OK, set +e
        set +e
        #su -c "source credentials/openrc && python functest/testcases/VIM/OpenStack/CI/libraries/run_rally.py functest/ all" ${USER}
        source credentials/openrc && python functest/testcases/VIM/OpenStack/CI/libraries/run_rally.py functest/ all
        set -e

        cp ~/functest/results/rally/*.html ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/rally/. || :
        cp ~/functest/results/rally/*.json ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/rally/. || :

        echo
        echo "========== Runing ODL test =========="
        RESULT="ERROR - OPNV Functional ODL test failed"
        STATUS="FUNCTEST_ODL"
        put_status

        source credentials/openrc
        functest/testcases/Controllers/ODL/CI/create_venv.sh
        functest/testcases/Controllers/ODL/CI/start_tests.sh

        mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/odl

        cp ./functest/testcases/Controllers/ODL/CI/logs/1/*.html ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/odl/.
        cp ./functest/testcases/Controllers/ODL/CI/logs/1/*.xml ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/odl/.

        echo
        echo "========== Runing vPING test =========="
        RESULT="ERROR - OPNV Functional vPING failed"
        STATUS="FUNCTEST_VPING"
        put_status

        # Redirect stdout to the log-file
        mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/vping
        touch ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/vping/result.log > /dev/null
        tail -n 0 -f ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log > ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}\
/test_result/vping/result.log &
        sleep 0.3
        VPING_LOGPID=$!

        pushd ${SCRIPT_PATH}
        source credentials/openrc
        python functest/testcases/vPing/CI/libraries/vPing.py -d functest/
        popd

        kill $VPING_LOGPID
    fi

    cd $PUSH_PATH
}

#
# END of func test
############################################################################

############################################################################
# Begin clean CI engine
#

function clean {
    # DEBUG Option, set ANY_CLEAN=0 if you want to preserve the environment untouched!
    DEBUG_ANY_CLEAN=1
    if [ $DEBUG_ANY_CLEAN -eq 1 ]; then
        PUSH_PATH=`pwd`
        echo
        echo "========== Cleaning up environment =========="
        STATUS="CLEANING"
        put_status

        cd ${SCRIPT_PATH}
        # <Fix> Such that clean up can use su
        #su -c "source credentials/openrc && python functest/testcases/config_functest.py -f -d functest/ clean" ${USER}
        if [ -e "credentials/openrc" ]; then
            cd ${SCRIPT_PATH} && source credentials/openrc && python functest/testcases/config_functest.py -f -d functest/ clean
        fi
        cd ${SCRIPT_PATH} && rm -rf functest
        cd ${HOME} && rm -rf functest
        cd ${SCRIPT_PATH} && rm -rf genesis
        cd ${SCRIPT_PATH} && rm -rf credentials/openrc*
        cd ${SCRIPT_PATH} && rm -rf output.txt

        # <FIX> Need to fix removal of virtual env.
        #    if [ $PURGE_MOST -eq 1 || $PURGE_ALL -eq 1 ]; then
        #      clean virt env
        #    fi
        #    if [ PURGE_ALL -eq 1 ]; then
        #      clean up ALL
        #    fi
    fi
cd $PUSH_PATH
}

#
# Begin clean CI engine
############################################################################

############################################################################
# BEGIN of variable declartion
#

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
HOME_SUFIX=${SCRIPT_PATH##/home/}
USER=${HOME_SUFIX%%/*}

if [ -z $HOME ]; then
   export HOME="/home/$USER"
fi

BUILD_CACHE="${SCRIPT_PATH}/cache"
BUILD_CACHE_URI="file://${BUILD_CACHE}"
BUILD_ARTIFACT_STORE="artifact"
RESULT_FILE="result.log"
VERSION=`date -u +%F--%H.%M`
ISO="opnfv-${VERSION}.iso"
ISO_META="${ISO}.txt"
BRANCH="master"
CHANGE_SET=""
if [ -n "${DEPLOYTGT}" ]; then
    DEPLOY_CONFIG=${DEPLOYTGT}
else
    DEPLOY_CONFIG="default_no_ha"
fi
STATUS_FILE_PATH="/var/run/fuel"
BUILD=1
DEPLOY=1
TEST=1
SMOKE=0
LOCAL_ISO_PROVIDED=0
CHANGE_SET_PROVIDED=0
LOCAL_REPO_PROVIDED=0
LOCAL_PATH_PROVIDED=0
BRANCH_PROVIDED=0
USER_PROVIDED=0
INVALIDATE_CACHE=0
PURGE_MOST=0
PURGE_ALL=0

#RESULT-CODES
RESULT="ERROR - Script initialization failed"
COMMIT_ID="NIL"
TOTAL_TIME=0
BUILD_TIME=0
DEPLOY_TIME=0
TEST_TIME=0
rc=1

#
# END of variable declartion
############################################################################

############################################################################
# Start of main
#

# Set less restrictive umask so that files are accessible by libvirt
umask 0002

# Add the path to the CI tools directory
export PATH=${SCRIPT_PATH}/tools:$PATH


if [ "$(id -u)" == "0" ]; then
   echo "This script MUST NOT be run as root" 1>&2
   usage
   exit 1
fi

while getopts "a:u:b:c:r:l:BDTi:tIpPh" OPTION
do
    case $OPTION in
        h)
            usage
            rc=0
            exit 0
            ;;
        a)
            DEPLOY_CONFIG=${OPTARG}
            ;;
        u)
            USER=${OPTARG}
            USER_PROVIDED=1
            ;;

        b)
            BRANCH=${OPTARG}
            BRANCH_PROVIDED=1
            echo "Branch set to $BRANCH"
            ;;

        c)
            CHANGE_SET=${OPTARG}
            CHANGE_SET_PROVIDED=1
            ;;

        l)
            LOCAL_PATH=${OPTARG}
            LOCAL_PATH_PROVIDED=1
            ;;
        r)
            LOCAL_REPO=${OPTARG}
            LOCAL_REPO_PROVIDED=1
            ;;

        B)
            BUILD=0
            ;;

        D)
            DEPLOY=0
            ;;

        T)
            TEST=0
            ;;

        i)
            LOCAL_ISO=${OPTARG}
            LOCAL_ISO_PROVIDED=1
            ;;

        t)
            SMOKE=1
            ;;

        I)
            INVALIDATE_CACHE=1
            ;;

        p)
            PURGE_MOST=1
            ;;

        P)
            PURGE_ALL=1
            ;;


        *)
            echo "${OPTION} is not a valid argument"
            exit 1
            ;;
    esac
done

shift $[OPTIND - 1]
LF_USER=$@
if [ $LOCAL_PATH_PROVIDED -eq 1 ]; then
    BRANCH="NIL"
    COMMIT_ID="NIL"
fi

# Enable the exit trap
trap do_exit SIGINT SIGTERM EXIT

cd ${SCRIPT_PATH}

# Redirect stdout and stderr to the log-file
mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}
touch ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log > /dev/null
tail -n 0 -f ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log 2>/dev/null &
sleep 0.3
LOGPID=$!
exec > ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log 2>&1

eval_params

check_avail

GIT_SRC="ssh://${LF_USER}@gerrit.opnfv.org:29418/genesis ${CHANGE_SET}"
GIT_HTTPS_SRC="https://gerrit.opnfv.org/gerrit/genesis"

echo "========== Running CI-pipeline with the following parameters =========="
echo "Starting CI with the following script options: $0 $@"
echo "Local user: ${USER}"
echo "LinuxFoundation Gerrit user: ${LF_USER}"
echo "Branch: ${BRANCH}"

echo "Version: ${VERSION}"
echo "Change-set: ${CHANGE_SET}"

if [ $LOCAL_PATH_PROVIDED -eq 1 ]; then
    METHOD="Local directory ${LOCAL_PATH}"
else
    if [[ -z $LF_USER ]]; then
        METHOD="https://"
    else
        METHOD="ssh://"
    fi
fi

echo "Repository clone method: $METHOD"
echo "Cache URI: ${BUILD_CACHE_URI}"
echo "Build artifact output: ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}"
echo "Local Repository: ${LOCAL_REPO}"
echo "Local ISO: ${LOCAL_ISO}"
if [ $BUILD -eq 0 ]; then
 echo "Build: ===Skip==="
else
 echo "Build: ===Staged==="
fi
if [ $DEPLOY -eq 0 ]; then
 echo "Deploy: ===Skip==="
else
 echo "Deploy: ===Staged==="
fi
if [ $TEST -eq 0 ]; then
 echo "Test: ===Skip==="
else
 echo "Test: ===Staged==="
fi
#<FIX> Temporary test stub - must be removed before <MERGE>
#echo "Test finished - exiting"
#RESULT="SUCCESS"
#rc=0
#exit 0

if [ $BUILD -eq 1 ]; then
    time0=`date +%s`
    clone_repo
    build
    time1=`date +%s`
    BUILD_TIME=$[(time1-time0)/60]
    echo
    echo "========== Build took ${BUILD_TIME} minutes =========="
else
    echo
    echo "========== Build skiped =========="
fi

if [ $DEPLOY -eq 1 ]; then
    time0=`date +%s`
    if [ -z "$REPO_PATH" ]; then
        clone_repo
    fi
    deploy
    time1=`date +%s`
    DEPLOY_TIME=$[(time1-time0)/60]
    echo
    echo "========== Deploy took ${DEPLOY_TIME} minutes =========="
else
    echo
    echo "========== Deploy skiped =========="
fi

if [ $TEST -eq 1 ]; then
    time0=`date +%s`
    func_test
    time1=`date +%s`
    TEST_TIME=$[(time1-time0)/60]
    echo
    echo "========== func test took ${TEST_TIME} minutes =========="
else
    echo
    echo "========== Func test skiped =========="
fi

RESULT="SUCCESS"
TOTAL_TIME=$[BUILD_TIME+DEPLOY_TIME+TEST_TIME]
echo
echo
echo "================================================================="
echo "========================= Total Sucess  ========================="
echo "==================== Total CI time: ${TOTAL_TIME} min ====================="
echo "============ Open OPNVF resources as indicated below: ==========="
echo "================ Fuel GUI: http://${FUEL_IP}:8000 ================"
echo "======== OpenStack Horizon GUI: http://${OS_IP}:80 =========="
echo "=========== OpenDaylight GUI: http://${OS_IP}:???? ============"
echo
if [ $BUILD -eq 1 ]; then
#  if .. provide status of used repo!
    echo "iso image is at: ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/${ISO}"
else
    echo "Status of repo/image unknown - local iso was used"
fi
echo "log file is at: ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log"
echo "test results are at: ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test-result/"
echo "================================================================="
echo
echo

rc=0
exit 0
#
# END of main
############################################################################
