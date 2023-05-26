#!/bin/bash
# Copyright 2023 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Final stage of the OFS FIM build flow. Compilation should be complete.
## Generates flash images and, if requested, an out-of-tree release.
##
## This script is typically invoked from build_top.sh and not by hand.
## The build_top.sh script parses command line arguments and maps them to
## environment variables.
##

set -e

if [ "$1" == "" ]; then
    echo "Usage: build_fim_finish.sh <build target> <work dir>" 1>&2
    exit 1
fi

#####################################################
### setup pre-requisite variables if not already set

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

########################################################
#### Load the board configuration

if [ "${BUILD_VAR_SETUP_COMPLETE}" != "1" ]; then
    source "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/build_var_setup_common.sh
    # source build var setup file again to print out env variables to log file
    source "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/build_var_setup_common.sh
fi

#################################################
######   setup OPAE SDK repo/build

# OPAE should have been loaded during build_fim_setup.sh if needed.
# Rerunning the script should use the result from setup.

echo "SETUP_OPAE_SDK_SH_FILE is $SETUP_OPAE_SDK_SH_FILE"
if [ ! -z ${ENA_OPAE_SDK_SETUP_FOR_FIM} ]; then
    if [ ${ENA_OPAE_SDK_SETUP_FOR_FIM} == '1' ]; then
        if [ -e ${SETUP_OPAE_SDK_SH_FILE} ]; then
            echo "Setting up OPAE SDK"
            source ${SETUP_OPAE_SDK_SH_FILE}
        else
            echo "Error: ${SETUP_OPAE_SDK_SH_FILE} not found"
            exit 1
        fi
    fi
fi

#################################################
######   State is loaded. Ready to work...

function chk_exit_code() {
    exit_code=${?}
    if [ "${exit_code}" != "0" ]; then
        echo "Error: ${1} failed. Exit code: ${exit_code}" 1>&2
        exit 1
    fi
    unset exit_code
}

echo ""
echo "Finishing compilation in ${WORK_SYN_TOP_PATH}"
echo ""


###################################
######   Generate Flash Image 

if [ ! -z ${ENA_FLASH} ]; then
    if [ "${ENA_FLASH}" == "1" ]; then
        echo "FLASH image generation enabled" 
        if [ -e ${WORK_SYN_TOP_PATH}/output_files/${Q_PROJECT}.sof ]; then
            if [ -d ${WORK_BUILD_FLASH_SH_PATH} ]; then
                # <project>.pfg file has relative reference to the output_files directory
                # so, build flash should be executed in the build_flash directory
                (cd $(dirname ${WORK_BUILD_FLASH_SH_FILE}) && ${WORK_BUILD_FLASH_SH_FILE})
                chk_exit_code "${WORK_BUILD_FLASH_SH_FILE}"
            else
                echo "Error: Cannot find ${WORK_BUILD_FLASH_SH_FILE} - Aborting Creation of flash images" 1>&2
                exit 1           
            fi
        else
            echo "Error: Cannot find sof file - Aborting creation of flash images" 1>&2
            exit 1
        fi
    fi
fi


#################################
#### Generate PR out-of-tree build environment

# The FIM is cabable of out-of-tree builds when ENA_PR_BUILD_TEMPLATE_GEN
# is set. Only generate the tree when DO_PR_BUILD_TEMPLATE_GEN is also set,
# either by the user or a parent script.
if [[ "${ENA_PR_BUILD_TEMPLATE_GEN}" == "1" && ! -z "${DO_PR_BUILD_TEMPLATE_GEN}" ]]; then
    PR_BUILD_DIR="${WORK_DIR}"/pr_build_template
    echo -e "\nGenerating PR build template tree in ${PR_BUILD_DIR}"

    BOARD_PATH="${OFS_BOARD_PATH}"
    if [ "${OFS_BOARD_VARIANT}" != "" ]; then
        BOARD_PATH="${BOARD_PATH}:${OFS_BOARD_VARIANT}"
    fi
    echo -e "Generating PR build for board ${BOARD_PATH}"

    "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/generate_pr_release.sh \
        -f -t "${PR_BUILD_DIR}" "${BOARD_PATH}" "${WORK_DIR}"
    chk_exit_code "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/generate_pr_release.sh
fi


#############################################
#### display timing pass/fail for FIM build

# Print a build summary. This script has no side effects.
"${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/display_timing_pass_fail.sh
