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
        echo "#################################################################"
        if [ -d  ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION} ]; then
            echo "FAILED - see the log for details: ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log"
        else
            echo "FAILED - see the log for details: ${RESULT_FILE}"
        fi
        echo "#################################################################"
    fi
    TOTAL_TIME=$[BUILD_TIME+DEPLOY_TIME+TEST_TIME];
    put_result;
    if [ -e ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log ]; then
        chown ${USER} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log
        chgrp ${GROUP} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log
    fi
    echo "result: $rc"
    # Note exit code 100 is a special code for no clean-up,
    # eg used when another instance is already running
    if [ $rc -ne 100 ]; then
        cd $SCRIPT_PATH
        clean;
        STATUS="IDLE"
        put_status
        sudo rm -f ${PID_LOCK_FILE}
    fi

     if [ ! -z ${LOGPID} ]; then
         kill $LOGPID
     fi
     if [ ! -z ${FUNC_TEST_LOGPID} ]; then
         kill ${FUNC_TEST_LOGPID}
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
    me=$(basename $0)
    pushd `pwd` &> /dev/null
    cat | more << EOF
$me - Simple Fuel@OPNFV CI Pipeline:
1) Clones and check-out Fuel@OPNFV from OPNFV Repos"
2) Builds Fuel@OPNFV
3) Deploys a Fuel@OPNFV using local nested KVM virtualization
4) Performs basic health tests
5) Perfoms ordinary OPNFV CI pipeline functional tests

usage: $me [-h] [-a deploy_config] [-u local user] |
       [-r local repo path | -l local path] [-b branch | -c change-set ] |
       [-BDT] [-t] [-i Iso image] [-p | -P] [-I]

-h Prints this message.
-a Deploys the named config from config/<Fuel version>/deploy_config. Defaults
   to "default_no_ha", or the content of the environment variable \$DEPLOYTGT.
-u local linux user, only needed if the script is not placed under the home of
   the user that should be used for non priviledged bash actions.
-r Path to a local repository rather than using standard Fuel@OPNFV repo, this
   option can not be combined with the -c, -l, or -B options.
-l Path to a local repository which will be used as is, including non
   staged/non tracked files, this option can not be combined with the -c, -r,
    -b, or -B options.
-b Upstream branch/change/tag to use, this option can not be combined with -B,
   -c or -r options.
-c Upstream commit to use, this option can not be combined with the -B, -b
   or -r options.
-I Invalidate cache, invalidates local cache and builds all from upstream,
   cannot be accompanioned with the -B option.
-B Skip build stage, this option cannot be combined with the -r, -b, -c or -D
   options.
-D Skip deploy stage, this option must either be accompanioned with the
   -i <iso> option or else it can not be accompanioned with the -B option
-T Skip functest stage
-t Only perform smoke test, this option can not be accompanioned with the
   -T option - NOT YET SUPPORTED
-i iso image (needed if build stage is skipped and no previous deployment
    exists), this option assumes the -B option.
-p Post run - Purge running deployment.
-P Post run - purge ALL, leaving the system as after ci_pipeline was cleanly
   installed. E.g. $me -P -BDT will clean ci_pipeline to it's install state.

Examples:
$me -b master - Clones-, Builds-, Deploys- & Functests the origin master
   branch
$me -b stable/arno - Clones-, Builds-, Deploys- & functests the origin
   stable/arno branc)
$me -b refs/changes/41/941/1 - Clones-, Builds-, Deploys- & functests
   the non-merged patch "/41/941/1"
$me -b master -DT - Clones- and builds origin master (omits deploy and functest)
$me -b master -T - Clones-, builds-, and deploys origin master (omits functest)
$me -BD - Tests an existing deployment
$me -b master -p -  Clones-, Builds-, Deploys- & Tests out of the master
   branch after which the the deployment environment is removed
$me -BDT -p - (Does nothing but) Purges previous virtual deployment
$me -BDT -P - (Does nothing but) Purges every thing  except the installation, leaving
    a fresh installation

NOTE: THIS SCRIPT MAY NOT BE RAN AS ROOT
EOF
    popd &> /dev/null
}
#
# END of usage description
############################################################################

############################################################################
# BEGIN of .yaml parser
#
function parse_yaml() {
    pushd `pwd` &> /dev/null
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
    popd &> /dev/null
}
#
# END of .yaml parser
############################################################################

############################################################################
# BEGIN of fetch_config
#
function fetch_config() {
    pushd `pwd` &> /dev/null

    # Parse config yaml files
    eval $(parse_yaml ${DEA} "dea_")
    eval $(parse_yaml ${DHA} "dha_")

    # Assign config variables
    # Todo: yaml parser need to improve such that it can parse arrays and catch OS_IP below
    FUEL_IP=$dea_fuel_ADMIN_NETWORK_ipaddress
    FUEL_GUI_USR=$dea_fuel_FUEL_ACCESS_user
    FUEL_GUI_PASSWD=$dea_fuel_FUEL_ACCESS_password
    FUEL_SSH_USR=$dha_nodes_username
    FUEL_SSH_PASSWD=$dha_nodes_password
    # TODO FIX ARRAY PARSING TO FETCH THE CONFIG BELOW, HARD CODED FOR NOW!
    MGMT_PHY_NETW=fuel1
    MGMT_VLAN=101
    MGMT_HOST_IP=192.168.0.66/24
    OS_IP="172.16.0.2"
    ADMIN_OS_USR="admin"
    ADMIN_OS_PASSWD=$dea_settings_editable_access_password_value

    popd &> /dev/null
}
#
# END of fetch_config
############################################################################


############################################################################
# BEGIN of repo setup functions
#
error_exit() {
    echo "$@" >&2
    exit 1
}

getspec() {
    git ls-remote $GIT_HTTPS_SRC | grep -v '\^' |  grep $1 | awk '{ print $2 }'
}

checkout() {
    ref=$(echo $1 | sed 's:[^/]*/[^/]*/::')

    git checkout $ref || error_exit "Could not checkout $ref"
    echo "Repo is populated"
}

get_heads() {
    echo "Getting branch $1"
    checkout $1
}

get_tags() {
    echo "Getting tag $1"
    checkout $1
}

get_changes() {
    git fetch $GIT_HTTPS_SRC $1 || error_exit "Could not fetch $1"
    git checkout FETCH_HEAD || error_exit "Could not checkout FETCH_HEAD"
    echo "Repo is populated"
}
#
# END of repo setup functions
############################################################################

############################################################################
# Start output of CI result
#
function put_result {
    pushd `pwd` &> /dev/null
    LOG_MSG="Result: ${RESULT} | Build Id: ${VERSION} | Branch: ${BRANCH} | Commit ID: ${COMMIT_ID} | Total ci pipeline time: ${TOTAL_TIME} min | Total build time: ${BUILD_TIME} min | Total deployment time: ${DEPLOY_TIME} | Total functest time: ${TEST_TIME}"
    echo $LOG_MSG >> ${SCRIPT_PATH}/${RESULT_FILE}
    if [ -d  ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION} ]; then
        echo $LOG_MSG > ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/${RESULT_FILE}
    fi
    popd &> /dev/null
}
#
# END of output
############################################################################

############################################################################
# Start report CI status
#
function put_status {
    pushd `pwd` &> /dev/null
    sudo mkdir -p ${STATUS_FILE_PATH}
    if [ ${STATUS} == "IDLE" ]; then
        sudo sh -c "echo \"${STATUS} | $('date')\" > ${STATUS_FILE}"
    else
        sudo sh -c "echo \"${STATUS} | $('date') | ${BRANCH} | ${COMMIT_ID} | ${VERSION}\" > ${STATUS_FILE}"
    fi
    popd &> /dev/null
}
#
# END report CI status
############################################################################

############################################################################
# Evaluate parameters
#
function eval_params {
    pushd `pwd` &> /dev/null

    if [ $LOCAL_PATH_PROVIDED -eq 1 ]; then
        if [ $LOCAL_REPO_PROVIDED -eq 1 ]; then
            echo "Cannot operate on a local path at the same time as requested to clone a local repo: -l $LOCAL_PATH -r $LOCAL_REPO"
            usage
            RESULT="ERROR - Faulty script input parameters"
            exit 1
        fi

        if [ $BRANCH_PROVIDED -eq 1 ]; then
            echo "Cannot operate on a local path while a branch is provided: -l $LOCAL_PATH -b $BRANCH"
            usage
            RESULT="ERROR - Faulty script input parameters"
            exit 1
        fi

        if [ $COMMIT_ID_PROVIDED -eq 1 ]; then
            echo "Cannot operate on a local path while a commit id is provided: -l $LOCAL_PATH -c $COMMIT_ID"
            usage
            RESULT="ERROR - Faulty script input parameters"
            exit 1
        fi

        if [ $BUILD -eq 0 ]; then
            echo "Providing a local path for build while omitting build doesn't make sense - nothing to do: -l $LOCAL_PATH -B"
            usage
            RESULT="ERROR - Faulty script input parameters"
            exit 1
        fi
    fi

    if [ $BRANCH_PROVIDED -eq 1 ] &&  [ $COMMIT_ID_PROVIDED -eq 1 ]; then
        echo "Specifying a branch -b $BRANCH and a commit id -c $COMMIT_ID simultaneously is not allowed"
        RESULT="ERROR - Faulty script input parameters"
        exit 1
    fi

    if [ $BUILD -eq 1 ] && [ $DEPLOY -eq 0 ] && [ $TEST -eq 1 ]; then
        echo "You need to deploy a build if you want to test it, option -D alone does not make sense. (-DT could make sense if you only want to build, or -BD if you want to test an existing deployment)"
        usage
        RESULT="ERROR - Faulty script input parameters"
        exit 1
    fi

    if [ $BUILD -eq 1 ]; then
        if [ $LOCAL_ISO_PROVIDED -eq 1 ]; then
            echo "Since build has not been disabled (-B) it makes no sense to provide a local iso (-i $LOCAL_ISO)"
            usage
            RESULT="ERROR - Faulty script input parameters"
            exit 1
        fi
    fi

    if [ $BUILD -eq 0 ]; then
        if [ $BRANCH_PROVIDED -eq 1 ] || [ $COMMIT_ID_PROVIDED -eq 1 ] || [ $LOCAL_REPO_PROVIDED -eq 1 ] || [ $LOCAL_PATH_PROVIDED -eq 1 ] || [ $INVALIDATE_CACHE -eq 1 ]; then
            echo "As build is disabled (-B), it does not make sense to specify either of the following options: a branch, a commit id (-c ...), a local repository (-r ...), a local path (-l ...), or to invalidate the build cache (-I)"
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
    popd &> /dev/null
}
#
# END Evaluate parameters
############################################################################

############################################################################
# Check CI-pipeline availability
#
function check_avail {
    pushd `pwd` &> /dev/null

    # Use a lockfile containing the pid of the running process
    # If script crashes and leaves lockfile around, it will have a different pid
    # and will not prevent script running again.
    #

    # create empty lock file if none exists
    sudo mkdir -p ${STATUS_FILE_PATH} &> /dev/null
    sudo touch ${PID_LOCK_FILE} &> /dev/null

    # if lastPID is not null and a process with that pid exist, exit
    set +e
    read lastPID < $PID_LOCK_FILE
    set -e
    if [ ! -z "$lastPID" -a -d /proc/$lastPID ]; then
        echo "CI-Pipline busy!"
        RESULT="INFO - CI-pipeline busy"
        rc=100
        exit 100
    fi

    if [ ! -z "$lastPID" ]; then
        PREVIOUS_CRASH=1
        echo "Previous run crashed, need to clean before continuing....."
        clean
        PREVIOUS_CRASH=0
    fi
    # save my pid in the lock file
    sudo sh -c "echo $$ > ${PID_LOCK_FILE}"

    popd &> /dev/null
}
#
# END Check CI-pipeline availability
############################################################################

############################################################################
# BEGIN of clone repo
#
function clone_repo {
    pushd `pwd` &> /dev/null
    RESULT="ERROR - GIT Cloning failed"
    STATUS="CLONING"
    put_status

    pushd ${SCRIPT_PATH}
    if [ ${LOCAL_PATH_PROVIDED} -eq 0 ]; then
        REPO_PATH=${SCRIPT_PATH}/"fuel"
        rm -rf ${REPO_PATH}
        if [ $LOCAL_REPO_PROVIDED -eq 1 ]; then
            echo
            echo "========== Cloning local ${LOCAL_REPO} =========="
            git clone ${LOCAL_REPO} ${REPO_PATH}
        else
            echo "========== Cloning repository ${GIT_HTTPS_SRC} =========="
            echo "GIT SRC: ${GIT_HTTPS_SRC}"
            git clone ${GIT_HTTPS_SRC} ${REPO_PATH}
        fi

        pushd ${REPO_PATH}
        if [ $COMMIT_ID_PROVIDED -eq 1 ]; then
            echo "========= Checking out commit id  ${COMMIT_ID} ========="
            if ! git checkout ${COMMIT_ID}; then
                echo "Could not checkout commit id $COMMIT_ID"
                exit 1
            fi
        elif [ $BRANCH_PROVIDED -eq 1 ]; then
            echo "========== Fetching ${BRANCH} =========="
            if ! get_$BRANCH_TYPE $BRANCH; then
                echo "Could not fetch $branch"
                exit 1
            fi
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
    popd &> /dev/null
}
#
# END of clone repo
############################################################################

############################################################################
# BEGIN of build
#
function build {
    pushd `pwd` &> /dev/null
    echo "========== Preparing build =========="
    RESULT="ERROR - Build failed"
    STATUS="BUILDING"
    put_status

    cd ${SCRIPT_PATH}
    mkdir -p ${BUILD_CACHE}
    mkdir -p ${BUILD_ARTIFACT_PATH}

    echo
    echo "========== Building  =========="
    if [ $INVALIDATE_CACHE -ne 1 ]; then
        pushd ${REPO_PATH}/fuel/ci
        echo ./build.sh -v ${VERSION} -c ${BUILD_CACHE_URI} ${BUILD_ARTIFACT_PATH}
        [ $DEBUG_DO_NOTHING -ne 1 ] && ./build.sh -v ${VERSION} -c ${BUILD_CACHE_URI} ${BUILD_ARTIFACT_PATH}
        [ $DEBUG_DO_NOTHING -eq 1 ] && mkdir -p ${BUILD_ARTIFACT_PATH} && touch ${BUILD_ARTIFACT_PATH}/opnfv-${VERSION}.iso && touch ${BUILD_ARTIFACT_PATH}/opnfv-${VERSION}.iso.txt
        popd
    else
        pushd ${REPO_PATH}/fuel/ci
        echo ./build.sh -v ${VERSION} -c ${BUILD_CACHE_URI} -f P ${BUILD_ARTIFACT_PATH}
        [ $DEBUG_DO_NOTHING -ne 1 ] && ./build.sh -v ${VERSION} -c ${BUILD_CACHE_URI} -f P ${BUILD_ARTIFACT_PATH}
        popd
    fi

    echo mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}
    mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}
    echo cp -f ${BUILD_ARTIFACT_PATH}/${ISO} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}
    cp -f ${BUILD_ARTIFACT_PATH}/${ISO} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}
    echo cp -f ${BUILD_ARTIFACT_PATH}/${ISO_META} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}
    cp -f ${BUILD_ARTIFACT_PATH}/${ISO_META} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}

    popd &> /dev/null
}
#
# END of build
############################################################################

############################################################################
# BEGIN of deploy
#
function deploy {
    local ISOFILE

    pushd `pwd` &> /dev/null
    echo
    echo "========== Deploying =========="
    RESULT="ERROR - Deploy failed"
    STATUS="DEPLOYING"
    put_status

    echo "Starting virtualization manager GUI"
    virt-manager &
    echo cd ${SCRIPT_PATH}

    cd ${SCRIPT_PATH}
    echo "Repo path is ${REPO_PATH}"

    if [ $BUILD -eq 1 ]; then
       ISOFILE=${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/${ISO}
    else
       ISOFILE=${LOCAL_ISO}
    fi


   if [ $DEBUG_DO_NOTHING -ne 1 ]; then
       FUEL_VERSION=$(7z x -so $ISOFILE version.yaml 2>/dev/null \
        | grep release | sed 's/.*: "\(...\).*/\1/')
   else
       FUEL_VERSION="6.1"
   fi

    if [ -n "${FUEL_VERSION}" ]; then
        echo "Fuel version is in ISO is ${FUEL_VERSION}"
    else
        echo "Error: Could not retrieve Fuel version from $ISOFILE"
        exit 1
    fi

    if [ -d "${SCRIPT_PATH}/config/${FUEL_VERSION}"  ]; then
        DEA=${SCRIPT_PATH}/config/${FUEL_VERSION}/${DEPLOY_CONFIG}/dea.yaml
        DHA=${SCRIPT_PATH}/config/${FUEL_VERSION}/${DEPLOY_CONFIG}/dha.yaml
        if [ ! -f $DEA ]; then
            echo "Could not find DEA file $DEA"
            exit 1
        fi

        if [ ! -f $DHA ]; then
            echo "Could not find DHA file $DHA"
            exit 1
        fi

        fetch_config

        sudo mkdir -p ${DEPLOYED_CFG_PATH}
        sudo cp -f ${DEA} ${DEPLOYED_CFG_PATH}/dea.yaml
        sudo cp -f ${DHA} ${DEPLOYED_CFG_PATH}/dha.yaml

        # Handle different deployer versions
        case "${FUEL_VERSION}" in
            "6.0")
                echo sudo python ${REPO_PATH}/fuel/deploy/deploy.py ${ISOFILE} ${DEA} ${DHA}
                sudo python ${REPO_PATH}/fuel/deploy/deploy.py ${ISOFILE} ${DEA} ${DHA}
                ;;
            *)
                echo sudo python ${REPO_PATH}/fuel/deploy/deploy.py -iso ${ISOFILE} -dea ${DEA} -dha ${DHA}
                [ $DEBUG_DO_NOTHING -ne 1 ] && sudo python ${REPO_PATH}/fuel/deploy/deploy.py -iso ${ISOFILE} -dea ${DEA} -dha ${DHA}
                ;;
        esac
    else
        echo "Error: No deploy config directory for ${VERSION}"
        exit 1
    fi
    popd &> /dev/null
}
#
# END of deploy
############################################################################

############################################################################
# BEGIN of func test
#
function func_test {
    pushd `pwd` &> /dev/null
    cd ${SCRIPT_PATH}
    echo
    echo "========== Preparing func test =========="
    RESULT="ERROR - OPNV Functional test setup failed"
    STATUS="FUNCTEST_PREP"
    put_status

    # Get deployed stack configuration
    echo "Get stack config...."
    DEA=${DEPLOYED_CFG_PATH}/dea.yaml
    DHA=${DEPLOYED_CFG_PATH}/dha.yaml

    if [ ! -f $DEA ]; then
        echo "Could not find deployed DEA file $DEA"
        exit 1
    fi

    if [ ! -f $DHA ]; then
        echo "Could not find deployed DHA file $DHA"
        exit 1
    fi

    fetch_config

    # Set up func-test docker connectivity
    MGMT_SUB_IF="${MGMT_PHY_NETW}.${MGMT_VLAN}"
    set +e
    sudo ip addr del dev ${MGMT_SUB_IF} &> /dev/null
    sudo ip link set ${MGMT_SUB_IF} down &> /dev/null
    sudo ip link delete ${MGMT_SUB_IF} &> /dev/null
    set -e

    echo "ip link add name ${MGMT_SUB_IF} link ${MGMT_PHY_NETW} type vlan id ${MGMT_VLAN}"
    sudo ip link add name ${MGMT_SUB_IF} link ${MGMT_PHY_NETW} type vlan id ${MGMT_VLAN}
    echo "ip link set ${MGMT_SUB_IF} up"
    sudo ip link set ${MGMT_SUB_IF} up
    echo "ip addr add ${MGMT_HOST_IP} dev ${MGMT_SUB_IF}"
    sudo ip addr add ${MGMT_HOST_IP} dev ${MGMT_SUB_IF}

    # Create result directories and files
    mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/tempest
    mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/rally
    mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/vping
    mkdir -p ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/odl
    touch ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/test_results.log > /dev/null

    # Pull func-test docker container
    docker pull ${DOCKER_FUNCTEST_IMG}

    # start functest docker container and bind mount the docker's /home/opnfv/result
    # to the artifact test_result directory
    FUNCTEST_CID=`docker run -dt -v ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result:/home/opnfv/result -e "INSTALLER_TYPE=fuel" -e "INSTALLER_IP=${FUEL_IP}" opnfv/functest`

    # Redirect stdout to the log-file
    tail -n 0 -f ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log > ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/test_results.log &
    sleep 0.3
    FUNC_TEST_LOGPID=$!

    echo
    echo "========== Running func tests =========="
    RESULT="ERROR OPNV Functional test failed"
    STATUS="FUNCTEST"
    put_status

    # Start functest script inside the docker container
    [ $DEBUG_DO_NOTHING -ne 1 ] && docker exec -t ${FUNCTEST_CID} /home/opnfv/repos/functest/docker/start.sh

    # Stop logging
    kill ${FUNC_TEST_LOGPID}

    # Copying and formatting test results to the artifact's test_reult directory
    docker exec -t ${FUNCTEST_CID} cp -f /home/opnfv/repos/rally/log.html /home/opnfv/result/rally/log.html
    docker exec -t ${FUNCTEST_CID} cp -f /home/opnfv/repos/rally/report.html /home/opnfv/result/rally/report.html

    sed -n "/Functest: run vPing/","/Functest: run ODL suite/p" ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/test_results.log | head -n -1 > ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/vping/test_results.log
    sed -n "/Functest: run ODL suite/","/Functest: run Functest Rally Bench suites/p" ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/test_results.log | head -n -1 > ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/odl/test_results.log
    sed -n "/Functest: run Tempest suite/","/Functest: copy results and clean Functest environment/p" ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/test_results.log | head -n -1 > ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/tempest/test_results.log
    sed -n "/Functest: run Functest Rally Bench suites/","/Functest: run Tempest suite/p" ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/test_results.log | head -n -1 > ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result/rally/test_results.log

    sudo chown -fR ${USER} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result
    sudo chgrp -fR ${GROUP} ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test_result

    popd &> /dev/null
}
#
# END of func test
############################################################################

############################################################################
# Begin clean CI engine
#
function clean {
    set +e
    pushd `pwd` &> /dev/null
    if [ $DEBUG_NO_CLEAN -eq 0 ]; then
        echo
        echo "========== Cleaning up environment =========="
        STATUS="CLEANING"
        put_status

        if [ ! -z ${FUNCTEST_CID} ]; then
            docker rm -f ${FUNCTEST_CID}
        fi

        cd ${SCRIPT_PATH} && rm -rf functest &> /dev/null
        cd ${HOME} && rm -rf functest &> /dev/null
        cd ${SCRIPT_PATH} && rm -rf fuel &> /dev/null
        cd ${SCRIPT_PATH} && rm -rf credentials/openrc* &> /dev/null
        cd ${SCRIPT_PATH} && rm -rf output.txt &> /dev/null
        sudo sh -c "cd ${SCRIPT_PATH} && fusermount -u ${SCRIPT_PATH}/fueltmp/origiso && rm -rf fueltmp" &> /dev/null
        docker rmi -f ${DOCKER_FUNCTEST_IMG}

        if [ $PREVIOUS_CRASH -eq 0 ]; then
            if [ $PURGE_ENV -eq 1 ] || [ $PURGE_ALL -eq 1 ]; then
                for vm in `cat /var/run/fuel/deployed_cfg/dha.yaml | grep libvirtName: | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//'`; do
                    echo "Destroying VM: $vm"
                    virsh destroy $vm &> /dev/null
                    virsh undefine $vm &> /dev/null
                done

                networks="fuel1 fuel2 fuel3 fuel4"
                for nw in ${networks}; do
                echo "Destroying network: $nw"
                virsh net-destroy $nw &> /dev/null
                virsh net-undefine $nw &> /dev/null
                done

                sudo rm -rf ${SCRIPT_PATH}/images &> /dev/null
            fi

            if [ $PURGE_ALL -eq 1 ]; then
                rm -rf ${BUILD_ARTIFACT_STORE} &> /dev/null
                sudo rm -rf ${STATUS_FILE_PATH} &> /dev/null
                rm -rf ${SCRIPT_PATH}/${RESULT_FILE} &> /dev/null
                rm -rf ${BUILD_CACHE} &> /dev/null
            fi
        fi
    fi
    popd &> /dev/null
    set -e
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
USER=`id -un`
GROUP=`id -gn`

if [ -z $HOME ]; then
   export HOME="/home/$USER"
fi

GIT_HTTPS_SRC="https://gerrit.opnfv.org/gerrit/fuel"
BUILD_CACHE="${SCRIPT_PATH}/cache"
BUILD_CACHE_URI="file://${BUILD_CACHE}"
BUILD_ARTIFACT_STORE="${SCRIPT_PATH}/artifact"
RESULT_FILE="result.log"
VERSION=`date -u +%F--%H.%M`
ISO="opnfv-${VERSION}.iso"
ISO_META="${ISO}.txt"
BRANCH="master"
BRANCH_TYPE="heads"
COMMITID=""
if [ -n "${DEPLOYTGT}" ]; then
    DEPLOY_CONFIG=${DEPLOYTGT}
else
    DEPLOY_CONFIG="default_no_ha"
fi

DOCKER_FUNCTEST_IMG="opnfv/functest"
STATUS_FILE_PATH="/var/run/fuel"
STATUS_FILE="${STATUS_FILE_PATH}/ci-status"
PID_LOCK_FILE="${STATUS_FILE_PATH}/PID"
DEPLOYED_CFG_PATH=${STATUS_FILE_PATH}/deployed_cfg

# Arg defaults
BUILD=1
DEPLOY=1
TEST=1
SMOKE=0
LOCAL_ISO_PROVIDED=0
COMMIT_ID_PROVIDED=0
LOCAL_REPO_PROVIDED=0
LOCAL_PATH_PROVIDED=0
BRANCH_PROVIDED=0
USER_PROVIDED=0
INVALIDATE_CACHE=0
PURGE_ENV=0
PURGE_ALL=0

# DEBUG OPTIONS:
DEBUG_DO_NOTHING=0
DEBUG_NO_CLEAN=0

# INIT VALUES:
RESULT="ERROR - Script initialization failed"
COMMIT_ID="NIL"
TOTAL_TIME=0
BUILD_TIME=0
DEPLOY_TIME=0
TEST_TIME=0
PREVIOUS_CRASH=0
rc=1
#
# END of variable declartion
############################################################################

############################################################################
# Start of main
#

# DEBUG Options
# Script development debug options - these options are intended to be used for
# the development- and verification of this script.
#
# DEBUG_DO_NOTHING=1 runs the pipeline without actually performing the time consuming
# tasks of build, deploy or test, but yet producing dummy dummy results needed to
# complete the pipeline run successfully.
# Default is: DEBUG_DO_NOTHING=0
#DEBUG_DO_NOTHING=1

# DEBUG Option, set DEBUG_NO_CLEAN=1 if you want to preserve the full environment
# untouched, and preserved after the pipeline run.
# Default is: DEBUG_NO_CLEAN=0
#DEBUG_NO_CLEAN=1

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
            ;;

        c)
            COMMIT_ID=${OPTARG}
            COMMIT_ID_PROVIDED=1
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
            echo "-t, smoke-test only, is not yet supported"
            exit 1
            ;;

        I)
            INVALIDATE_CACHE=1
            ;;

        p)
            PURGE_ENV=1
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

if [ $LOCAL_PATH_PROVIDED -eq 1 ] || [ $BUILD -eq 0 ]; then
    BRANCH="NIL"
    COMMIT_ID="NIL"
fi

eval_params

# Validate branch/change/tag
if [ $BRANCH_PROVIDED -eq 1 ]; then
    BRANCH=$2

    matchcnt=$(getspec $BRANCH | wc -l)
    if [ $matchcnt -eq 0 ]; then
        echo "Could not find a match for $BRANCH"
        exit 1
    elif [ $matchcnt -gt 1 ]; then
        echo "$BRANCH was ambigious, can be one of:"
        getspec $BRANCH
        exit 1
    else
        BRANCH=$(getspec $BRANCH)
        BRANCH_TYPE=$(echo $BRANCH | cut -d "/" -f 2)
        echo "Will checkout $BRANCH of type $BRANCH_TYPE"
    fi
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

check_avail

echo "========== Running CI-pipeline with the following parameters =========="
echo "Starting CI with the following script options: $0 $@"
echo "Local user: ${USER}"
echo "Branch: ${BRANCH}"

echo "Version: ${VERSION}"
echo "Change-set: ${CHANGE_SET}"

if [ $LOCAL_PATH_PROVIDED -eq 1 ]; then
    METHOD="Local directory ${LOCAL_PATH}"
else
    METHOD="https://"
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
echo "#################################################################"
echo "================================================================="
echo "                          Total Sucess                           "
echo "                     Total CI time: ${TOTAL_TIME} min            "
echo "================================================================="
echo
echo "================================================================="
if [ $BUILD -eq 1 ]; then

    echo "Build iso image is at: ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/${ISO}"
    if [ $LOCAL_PATH_PROVIDED -ne 1 ]; then
        echo "It was built from repository sha1: `cd ${REPO_PATH} && git rev-parse HEAD`"
    else
        echo "It was built from local path: ${LOCAL_PATH}"
    fi
else
    if [ $DEPLOY -eq 1 ]; then
        echo "Status of repository is unknown - local iso: $LOCAL_ISO was used"
    else
        if [ $TEST -eq 1 ]; then
            echo "Status of repository and iso is unknown - performed functest on existing deployment"
        else
            echo "No Build- Deploy- or functest was run - no artifacts except logs were produced"
        fi
    fi
fi
echo "================================================================="
echo

if [ $DEPLOY -eq 1 ]; then
    echo "================================================================="
    echo "Access the deployed OPNVF resources as indicated below:"
    echo "Fuel GUI: http://${FUEL_IP}:8000"
    echo "OpenStack Horizon GUI: http://${OS_IP}:80"
    echo "================================================================="
    echo
fi

if [ $TEST -eq 1 ]; then
    echo "================================================================="
    echo "test results are at: ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/test-result/"
    echo "================================================================="
    echo
fi

echo "================================================================="
echo "log file is at: ${BUILD_ARTIFACT_STORE}/${BRANCH}/${VERSION}/ci.log"
echo "================================================================="
echo "#################################################################"
echo

rc=0
exit 0
#
# END of main
############################################################################
