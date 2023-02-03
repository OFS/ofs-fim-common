#!/bin/bash

set -e

#FUTURE_IMPROVEMENT:  
#   - add launch check to prevent using sh <sript>
#   - add checks if missing env variables
#   - add linear seed sweep capability


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


# set WORK_DIR if running this script directly
if [ -z WORK_DIR ]; then
    if [ -z ${1} ]; then 
        WORK_DIR="work"
    else
        WORK_DIR="${1}"
    fi
fi

function chk_exit_code() {
    exit_code=${?}
    if [ "${exit_code}" != "0" ]; then
        echo "Error: ${1} failed. Exit code: ${exit_code}" 1>&2
        exit 1
    fi
    unset exit_code
}


########################################################
#### build env setup
#### source env setup script if not already sourced
#### for build_top.sh is the entry point for the build
#### if running this script alone, need to setup BUILD_VAR_SETUP_SH_PATH

if [ "${BUILD_VAR_SETUP_COMPLETE}" != "1" ]; then
    if [ -z ${BUILD_VAR_SETUP_SH_PATH} ]; then
        echo "Error: BUILD_VAR_SETUP _SH_PATH variable is not set" 1>&2
        echo "       Must be pointed to the build_var_setup.sh of the target OFS_PROJECT" 1>&2
        exit 1
    fi

    echo ""
    echo "Setting up build variables"
    echo "Sourcing ${BUILD_VAR_SETUP_SH_PATH}/build_var_setup.sh"
    echo ""
    source ${BUILD_VAR_SETUP_SH_PATH}/build_var_setup.sh
    chk_exit_code "${BUILD_VAR_SETUP_SH_PATH}/build_var_setup.sh"

    echo "Done setting up build variables"
fi


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
#   check UPDATE_FME_IFC_ID_PY_PATH
#   check FME_ID_MIF_PATH
#   check FLOW_TCL_PATH
#   check SETUP_TCL_PATH
#   check REPORT_TIMING_TCL_PATH
#   check SYN_TOP_PATH
#   check BUILD_FLASH_SH_PATH


# change dir into the directory where the quartus project is.
ORIG_DIR=${PWD}
cd ${WORK_SYN_TOP_PATH}
chk_exit_code "cd ${WORK_SYN_TOP_PATH}"

# If there is an old output_files directory then remove it
rm -rf output_files

# Relative path from the Quartus build directory to the root of the
# build tree. This variable may be used in Quartus scripts to import
# source files. A relative path simplifies creation of Quartus
# archives, used by the PR flow.
# realpath is from GNU coreutils
export BUILD_ROOT_REL=$(realpath --relative-to=. "${WORK_DIR}")
echo "BUILD_ROOT_REL = ${BUILD_ROOT_REL}"
if [ -z "${BUILD_ROOT_REL}" ]; then
    echo "Error finding relative path from Quartus synthesis directory:" 1>&2
    echo "    ${PWD}" 1>&2
    echo "to work directory:" 1>&2
    echo "    ${WORK_DIR}" 1>&2
    exit 1
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
EOF

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
###### Checking if it is signaltap build
if [ ! -z ${SIGNALTAP_ENABLE_SCRIPT_SH_FILE} ]; then
    if [ -e ${SIGNALTAP_ENABLE_SCRIPT_SH_FILE} ]; then
        source ${SIGNALTAP_ENABLE_SCRIPT_SH_FILE}
    else
        echo "Error: ${SIGNALTAP_ENABLE_SCRIPT_SH_FILE} not found"
        exit 1
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
        echo "Running setup IP_LIB script: ${WORK_SETUP_IP_LIB_SH_FILE}"
        ${WORK_SETUP_IP_LIB_SH_FILE}
        chk_exit_code "${WORK_SETUP_IP_LIB_SH_FILE}"
    fi
fi

############################################
######## Quartus Compilation 

# Just a syntax test?
if [ ! -z ${ANALYSIS_AND_ELAB_ONLY} ]; then
    CMD="quartus_ipgenerate ${Q_PROJECT} -c ${Q_REVISION} --generate_project_ip_files --synthesis=verilog --parallel=on"
    ${CMD}
    chk_exit_code "${CMD}"
    CMD="quartus_syn ${Q_PROJECT} -c ${Q_REVISION} --analysis_and_elaboration"
    ${CMD}
    chk_exit_code "${CMD}"
    exit 0
fi


# update_qsf file with SEED value
sed -i "s/SEED *[0-9]*/SEED ${SEED}/" ${WORK_SYN_TOP_PATH}/${Q_PROJECT}.qsf
echo "Updated ${WORK_SYN_TOP_PATH}/${Q_PROJECT}.qsf with SEED: ${SEED}"

###########################################################################
######## Select U-Boot Firmware depending on whether or not VAB is enabled.
######## This is valid for N600x only, as the repo for this board core is the one that selects the U-Boot software dynamically.
######## Currently, this is statically set in C6100x repo -- therefore no dynamic selection is required.

if [[ $OFS_BOARD_CORE =~ n600 ]]; then
   echo ">>> Copying U-Boot Firmware file to ${WORK_SYN_TOP_PATH}/"
   if grep -q "ENABLE_MULTI_AUTHORITY\s\+ON" ${WORK_SYN_TOP_PATH}/${Q_PROJECT}.qsf; then
      if [ -f "${OFS_ROOTDIR}/syn/common/setup/vab_sw/u-boot-spl-dtb.hex" ]; then
         echo "    Using VAB-enabled firmware in build: ${OFS_ROOTDIR}/syn/common/setup/vab_sw/u-boot-spl-dtb.hex"
         cp ${OFS_ROOTDIR}/syn/common/setup/vab_sw/u-boot-spl-dtb.hex ${WORK_SYN_TOP_PATH}/
      else
         echo "    Error: VAB-enabled firmware file: ${OFS_ROOTDIR}/syn/common/setup/vab_sw/u-boot-spl-dtb.hex could not be found."
      fi
   else
      if [ -f "${OFS_ROOTDIR}/syn/common/setup/non_vab_sw/u-boot-spl-dtb.hex" ]; then
         echo "    Using non-VAB-enabled firmware in build: ${OFS_ROOTDIR}/syn/common/setup/non_vab_sw/u-boot-spl-dtb.hex"
         cp ${OFS_ROOTDIR}/syn/common/setup/non_vab_sw/u-boot-spl-dtb.hex ${WORK_SYN_TOP_PATH}/
      else
         echo "    Error: non-VAB-enabled firmware file: ${OFS_ROOTDIR}/syn/common/setup/non_vab_sw/u-boot-spl-dtb.hex could not be found."
      fi
   fi
fi


# option to skip compile
if [ ! -z ${ENA_FIM_COMPILE} ]; then
    if [ ${ENA_FIM_COMPILE} == "1" ]; then
        if quartus_sh -t ${FLOW_TCL_FILE} -setup_script ${SETUP_TCL_FILE} -base; then
           quartus_sta -t ${REPORT_TIMING_TCL_FILE} --project=${Q_PROJECT} --revision=${Q_REVISION}
        else
            echo "Error: ${OFS_PROJECT} Build failed!" 1>&2
            exit 1
        fi
    else
        echo "Skipping FIM compile"
        echo "ENA_FIM_COMPILE= ${ENA_FIM_COMPILE}"
    fi
fi

#########################################
#####  setup for PR

if [ ! -z ${ENA_PR_SETUP} ]; then
    if [ ${ENA_PR_SETUP} == "1" ]; then
        echo "PR SETUP"
        # create sdc file for PR 
        ${PR_SETUP_SH_FILE}
        chk_exit_code "${PR_SETUP_SH_FILE}"
    fi
fi


#########################################
#####  Optional post-compile script

if [ ! -z "${ENA_POST_COMPILE_SCRIPT}" ]; then
    if [ "${ENA_POST_COMPILE_SCRIPT}" == "1" ]; then
        echo "Running post compile script: ${WORK_POST_COMPILE_SCRIPT_SH_FILE}"
        ${WORK_POST_COMPILE_SCRIPT_SH_FILE}
        chk_exit_code "${WORK_POST_COMPILE_SCRIPT_SH_FILE}"
    fi
fi


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

    (cd "${ORIG_DIR}" && \
     "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/generate_pr_release.sh \
        -f -t "${PR_BUILD_DIR}" "${BOARD_PATH}" "${WORK_DIR}")
    chk_exit_code "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/generate_pr_release.sh
fi


#############################################
#### display timing pass/fail for FIM build

if [ ! -z ${ENA_PRINT_TIMING_STATUS} ]; then
    if [ "${ENA_PRINT_TIMING_STATUS}" == "1" ]; then
        ${DISPLAY_TIMING_PASS_FAIL_SH_FILE}
        chk_exit_code "${DISPLAY_TIMING_PASS_FAIL_SH_FILE}"
    fi
fi
