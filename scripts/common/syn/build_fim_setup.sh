#!/bin/bash
# Copyright 2023 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Setup stage of the OFS FIM build flow. Creates a work tree with a Quartus
## FIM project.
##
## This script is typically invoked from build_top.sh and not by hand.
## The build_top.sh script parses command line arguments and maps them to
## environment variables.
##

set -e

if [ "$1" == "" ]; then
    echo "Usage: build_fim_setup.sh <build target> [<work dir>]" 1>&2
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

function chk_exit_code() {
    exit_code=${?}
    if [ "${exit_code}" != "0" ]; then
        echo "Error: ${1} failed. Exit code: ${exit_code}" 1>&2
        exit 1
    fi
    unset exit_code
}


##################################
######  Create Work directory

if [ ! -z ${ENA_CREATE_WORK_DIR} ]; then
    if [ ${ENA_CREATE_WORK_DIR} == "1" ]; then
        echo ""
        ${CREATE_WORK_DIR_SH_FILE} ${KEEP_WORK_ARG} ${WORK_DIR}
        chk_exit_code "${CREATE_WORK_DIR_SH_FILE}"
    else
        echo ""
        echo "Skipping create work directory"
        echo "ENA_CREATE_WORK_DIR = ${ENA_CREATE_WORK_DIR}"
    fi
fi

# FUTURE_IMPROVEMENT:
#   check FME_ID_MIF_PATH
#   check FLOW_TCL_PATH
#   check SETUP_TCL_PATH
#   check REPORT_TIMING_TCL_PATH
#   check SYN_TOP_PATH
#   check BUILD_FLASH_SH_PATH

if [ ! -d "${WORK_DIR}" ]; then
    echo "Error: ${WORK_DIR} not found!"
    exit 1
fi
if [ ! -d "${WORK_SYN_TOP_PATH}" ]; then
    echo "Error: build root ${WORK_SYN_TOP_PATH} not found!"
    exit 1
fi

# Create a link from WORK_DIR to WORK_SYN_TOP_PATH so that the
# Quartus build directory can be found from WORK_DIR without
# using any environment variables.
#
# realpath is from GNU coreutils.
(cd "${WORK_DIR}" && rm -f quartus_proj_dir &&
     ln -s $(realpath --relative-to=. "${WORK_SYN_TOP_PATH}") quartus_proj_dir)

# change dir into the directory where the quartus project is.
cd ${WORK_SYN_TOP_PATH}
chk_exit_code "cd ${WORK_SYN_TOP_PATH}"

# If there is an old output_files directory then remove it
rm -rf output_files

# Relative path from the Quartus build directory to the root of the
# build tree. This variable may be used in Quartus scripts to import
# source files. A relative path simplifies creation of Quartus
# archives, used by the PR flow.
export BUILD_ROOT_REL=$(realpath --relative-to=. "${WORK_DIR}")
echo "BUILD_ROOT_REL = ${BUILD_ROOT_REL}"
if [ -z "${BUILD_ROOT_REL}" ]; then
    echo "Error finding relative path from Quartus synthesis directory:" 1>&2
    echo "    ${PWD}" 1>&2
    echo "to work directory:" 1>&2
    echo "    ${WORK_DIR}" 1>&2
    exit 1
fi

# These Tcl scripts will be needed by PR, including out-of-tree PR
# compilation. Set them up now so that the entire environment is
# configured before Quartus runs.
if [ "X${ENA_PR_SETUP}" == "X1" ]; then
    mkdir -p ofs_partial_reconfig
    for t in ofs_sta_report_script_pr.tcl user_clock_freqs_compute.tcl report_timing.tcl user_clocks.sdc gen_gbs.tcl tcl_lib; do
        if [ ! -e ofs_partial_reconfig/${t} ]; then
            ln -s ../"${BUILD_ROOT_REL}"/ofs-common/scripts/common/syn/${t} ofs_partial_reconfig/
        fi
    done
fi

# Copy config_env.tcl to a well known location since it must be discoverable
# without BUILD_ROOT_REL.
echo  "WORK_DIR = ${WORK_DIR}"
mkdir -p ../setup
if [ ! -e ../setup/config_env.tcl ]; then
    ln -s "${WORK_DIR}"/ofs-common/scripts/common/syn/config_env.tcl ../setup
fi

# Save state to the file that config_env.tcl loads
cat > build_env_db.txt <<EOF
# Build configuration written by build_fim.sh. This file is loaded
# into the Quartus project by config_env.tcl.

BUILD_ROOT_REL=${BUILD_ROOT_REL}
BITSTREAM_ID=${BITSTREAM_ID}
BITSTREAM_MD=${BITSTREAM_MD}
BITSTREAM_INFO=${BITSTREAM_INFO}
Q_REVISION=${Q_REVISION}
EOF

if [ ! -z ${Q_PR_REVISION} ]; then
    echo "Q_PR_REVISION=${Q_PR_REVISION}" >> build_env_db.txt
    echo "Q_PR_PARTITION_NAME=${Q_PR_PARTITION_NAME}" >> build_env_db.txt
fi

# All the environment variables passed to build_env_db.txt must be defined
if [ $(grep -c '=$' build_env_db.txt) != 0 ]; then
    echo "Error -- undefined environment variables:"
    grep '=$' build_env_db.txt | sed 's/=$//'
    exit 1
fi

env | grep "^OFS_BUILD_TAG_" | cat >> build_env_db.txt


######################################################
########  Swap symlink for copied files
########  Preserves source tree 

# copy over fme_id.mif and qsf as these files will be modified per build

# remove possible symlink before copying
rm -f ${WORK_FME_ID_MIF_FILE}
cp -f ${FME_ID_MIF_FILE} ${WORK_FME_ID_MIF_FILE}
chk_exit_code "cp ${FME_ID_MIF_FILE} ${WORK_FME_ID_MIF_FILE}"


# remove possible symlink before copying
# need hard copy of QSF and QPF file as Quartus will modify them (don't want to pollute source tree)
for q in ${SYN_TOP_PATH}/*.q[ps]f; do
    fn=$(basename "${q}")
    if [ -L "${WORK_SYN_TOP_PATH}/$fn" ]; then
        rm -f "${WORK_SYN_TOP_PATH}/$fn"
        cp "${q}" "${WORK_SYN_TOP_PATH}"/
        chk_exit_code "cp .qsf/.qpf"
    fi
done


#################################################
######   optional pre-compile script
if [ ! -z ${ENA_PRE_COMPILE_SCRIPT} ]; then
    if [ "${ENA_PRE_COMPILE_SCRIPT}" == "1" ]; then
        echo "Running pre compile script: ${WORK_PRE_COMPILE_SCRIPT_SH_FILE}"
        ${WORK_PRE_COMPILE_SCRIPT_SH_FILE}
        chk_exit_code "${WORK_PRE_COMPILE_SCRIPT_SH_FILE}"
    fi
fi

#################################################
######   setup OPAE SDK repo/build 
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
######   setup PIM and possibly AFU sources
if [ -z "${OFS_PLATFORM_AFU_BBB}" ]; then
    source "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/pim/setup_ofs_platform_afu_bbb.sh
else
    echo "Using provided OFS_PLATFORM_AFU_BBB=${OFS_PLATFORM_AFU_BBB}"
fi
"${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/pim/ofs_pim_and_afu_config.sh -s

################################################
######   run IP_LIB setup script

if [ ! -z ${ENA_SETUP_IP_LIB_SCRIPT} ]; then
    if [ "${ENA_SETUP_IP_LIB_SCRIPT}" == "1" ]; then
        echo "Setting up ../ip_lib/"
        CMD="quartus_ipgenerate -t ${OFS_ROOTDIR}/ofs-common/scripts/common/syn/emit_project_ip.tcl --project=${Q_PROJECT} --revision=${Q_REVISION} --mode=ip_lib"
        ${CMD}
        chk_exit_code "${CMD}"
    fi
fi

###########################################################################
######## Select U-Boot Firmware depending on whether or not VAB is enabled.
######## This is valid for N600x only, as the repo for this board core is the one that selects the U-Boot software dynamically.
######## Currently, this is statically set in C6100x repo -- therefore no dynamic selection is required.

if [[ $OFS_BOARD_CORE =~ n600 ]]; then
   echo ">>> Copying U-Boot Firmware file to ${WORK_SYN_TOP_PATH}/"
   if grep -q "ENABLE_MULTI_AUTHORITY\s\+ON" ${WORK_SYN_TOP_PATH}/${Q_PROJECT}.qsf; then
      if [ -f "${OFS_ROOTDIR}/syn/setup/vab_sw/u-boot-spl-dtb.hex" ]; then
         echo "    Using VAB-enabled firmware in build: ${OFS_ROOTDIR}/syn/setup/vab_sw/u-boot-spl-dtb.hex"
         cp ${OFS_ROOTDIR}/syn/setup/vab_sw/u-boot-spl-dtb.hex ${WORK_SYN_TOP_PATH}/
      else
         echo "    Error: VAB-enabled firmware file: ${OFS_ROOTDIR}/syn/setup/vab_sw/u-boot-spl-dtb.hex could not be found."
      fi
   else
      if [ -f "${OFS_ROOTDIR}/syn/setup/non_vab_sw/u-boot-spl-dtb.hex" ]; then
         echo "    Using non-VAB-enabled firmware in build: ${OFS_ROOTDIR}/syn/setup/non_vab_sw/u-boot-spl-dtb.hex"
         cp ${OFS_ROOTDIR}/syn/setup/non_vab_sw/u-boot-spl-dtb.hex ${WORK_SYN_TOP_PATH}/
      else
         echo "    Error: non-VAB-enabled firmware file: ${OFS_ROOTDIR}/syn/setup/non_vab_sw/u-boot-spl-dtb.hex could not be found."
      fi
   fi
fi

################################################
######   Pre-populate PR revisions

if [[ "${ENA_PR_SETUP}" == "1" && ! -z "${Q_PR_REVISION}" ]]; then
    quartus_sh --prepare -r ${Q_PR_REVISION} ${Q_PROJECT}
    # Make the base revision the default
    quartus_sh --prepare -r ${Q_REVISION} ${Q_PROJECT}
fi
