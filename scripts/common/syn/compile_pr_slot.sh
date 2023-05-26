#!/bin/bash
# Copyright (C) 2021-2023 Intel Corporation
# SPDX-License-Identifier: MIT

# Identify this compile is a PR compile to setup.tcl (can be used in other scripts)
export PR_COMPILE="1"


#check for $OFS_ROOTDIR and set to cloned repo toplevel path
if [ -z ${OFS_ROOTDIR} ]; then
    echo "Warning: OFS_ROOTDIR is not set"
    echo "Deriving OFS_ROOTDIR from git clone directory..."
    export OFS_ROOTDIR="$(git rev-parse --show-toplevel)" 
    # check if in a cloned/downloaded repo"
    if [ ${?} != "0" ]; then
        #not in git cloned repo and OFS_ROOTDIR not set: error out.
        echo "Error: OFS_ROOTDIR not set and cannot derive toplevel path from git command" 1>&2
        echo "       Please set OFS_ROOTDIR" 1>&2
        exit 1
    fi
    echo "OFS_ROOTDIR now set to: ${OFS_ROOTDIR}"
fi

################################
### check error code function

function chk_exit_code() {
    exit_code=${?}
    if [ "${exit_code}" != "0" ]; then
        echo "Error: ${1} failed. Exit code: ${exit_code}" 1>&2
        exit 1
    fi
    unset exit_coded
}


##################################
####  Check build target argument

if [ -z "${1}" ]; then
    echo "Error: no arguments" 1>&2
    echo "Usage: ${0} <build target> <work dir name>" 1>&2
    exit 1
fi


#################################
###   Set WORK directory
###   checks on WORK directory done in work dir creation script
:
if [ -z "${2}" ]; then
    export WORK_DIR="${OFS_ROOTDIR}/work"
else
    if [ "$(dirname ${2})" == "." ]; then
        #passing in a name, append OFS_ROOTDIR to the path
        export WORK_DIR="${OFS_ROOTDIR}/${2}"
    else
        #passing in a path, us as-is
        export WORK_DIR="${2}"
    fi
fi


################################
###   set PR build env variables
export OFS_BOARD_PATH=${1}
#if [ ! -d "${OFS_ROOTDIR}/syn/${OFS_BOARD_PATH}" ]; then
#    echo "OFS platform path ${OFS_ROOTDIR}/ofs-common/syn/${OFS_BOARD_PATH} not found"
#    exit 1
#fi

if [ "X${BUILD_VAR_SETUP_COMPLETE}" == "X" ]; then
    source "${OFS_ROOTDIR}/ofs-common/scripts/common/syn/build_var_setup_common.sh"
    chk_exit_code "source ${OFS_ROOTDIR}/ofs-common/scripts/common/syn/build_var_setup_common.sh"
    # run the 2nd time to display the env variable
    "${OFS_ROOTDIR}/ofs-common/scripts/common/syn/build_var_setup_common.sh"
else
    # if BUILD_VAR_SETUP_COMPLETE is defined build_var_setup.sh has completed
    # run one more time to display env variables
    "${OFS_ROOTDIR}/ofs-common/scripts/common/syn/build_var_setup_common.sh"
    chk_exit_code "source ${OFS_ROOTDIR}/ofs-common/syn/common/scripts/build_setup.sh"
fi


###############################
###     OPAE SDK setup
###

# run the script to setup opae-sdk 
if [ ! -z ${ENA_OPAE_SDK_SETUP_FOR_PR} ]; then
    if [ ${ENA_OPAE_SDK_SETUP_FOR_PR} == '1' ]; then
        if [ -e ${SETUP_OPAE_SDK_SH_FILE} ]; then
            echo "Setting up OPAE SDK"
            source ${SETUP_OPAE_SDK_SH_FILE} 
            chk_exit_code "source ${SETUP_OPAE_SDK_SH_FILE}"
        else
            echo "Error: ${SETUP_OPAE_SDK_SH_FILE} not found"
            exit 1
        fi
    fi
fi

#################################################
######   setup PIM and possibly AFU sources
if [ -z "${OFS_PLATFORM_AFU_BBB}" ]; then
    source "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/pim/setup_ofs_platform_afu_bbb.sh
else
    echo "Using provided OFS_PLATFORM_AFU_BBB=${OFS_PLATFORM_AFU_BBB}"
fi
"${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/pim/ofs_pim_and_afu_config.sh -s

##############################
###     compile PR 
###     Build PR Slot

# Use the standard Quartus compilation flow
(cd "${WORK_SYN_TOP_PATH}" && \
  quartus_sh --flow compile ${Q_PROJECT} -c ${Q_PR_REVISION})

# check if build failed
if [ ! -f ${WORK_PR_RBF_FILE} ]; then
    echo "RBF file not found: ${WORK_PR_RBF_FILE}"
    exit 1
fi

# confirm that GBS file was created
if [ ! -f "${WORK_PR_GBS_FILE}" ]; then
    echo "GBS file not found: ${WORK_PR_GBS_FILE}"
    exit 1
fi

##
## For systems with signed images and a root key hash, PACSign must be used here
## to secure the GBS file.
##
## PACSign gbs file to create _unsigned.gbs (for open boards - no root key hash)
## -- create unsigned PR GBS image for fpgasupdate tool
if which PACSign &> /dev/null ; then
    PACSign PR -y -v -t UPDATE -H openssl_manager -i ${WORK_PR_GBS_FILE} -o "${WORK_PR_PACSIGN_GBS_FILE}"
    chk_exit_code "PACSign PR -y -v -t UPDATE -H openssl_manager -i ${WORK_PR_GBS_FILE} -o ${WORK_PR_PACSIGN_GBS_FILE}"
else
    echo "PACSign not found! Please manually sign ${WORK_PR_GBS_FILE}"
fi

# display work directory and artifact directory

echo ""
echo "Compile work directory:     ${WORK_SYN_TOP_PATH}"
echo "Compile artifact directory: ${WORK_SYN_TOP_PATH}/output_files"

echo ""

echo "******************************************"
echo "***          PR COMPILE"
echo "***"
echo "***        OFS_PROJECT:         ${OFS_PROJECT}"
if [ "${OFS_FIM}" != "." ] && [ "${OFS_FIM}" != "" ]; then
    echo "***        OFS_FIM:       ${OFS_FIM}"
fi
if [ "${OFS_BOARD}" != "." ] && [ "${OFS_BOARD}" != "" ]; then
    echo "***        OFS_BOARD:       ${OFS_BOARD}"
fi
echo "***        Q_PROJECT:           ${Q_PROJECT}"
echo "***        Q_PR_REVISION:       ${Q_PR_REVISION}"
echo "***        Q_PR_PARTITION_NAME: ${Q_PR_PARTITION_NAME}"
echo "***        PR Build Complete"

# clocks.sta.fail.summary filesize > 0 if timing failed (contains collection of failed clock domains)
if [ ! -s ${WORK_SYN_TOP_PATH}/output_files/timing_report/clocks.sta.fail.summary ]; then
    echo "***        Timing Passed!"
else
    echo "***        Timing FAILED!!!"
fi
echo "***"
echo "******************************************"
