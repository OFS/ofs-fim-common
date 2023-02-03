#!/bin/bash

# This script is to setup env variables for OFS-D5005 build
# 

# enforce sourcing this script
# Note that this section needs to be the first thing this script does
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    echo "This script sets up env variables used by the build scripts"
    echo "Script must be sourced"
    echo "Usage: source ${BASH_SOURCE[0]}"
    exit 1
fi

# Sourcing this script again should display the environment settings
if [ ! -z ${BUILD_VAR_SETUP_COMPLETE} ]; then
    # print env variables only if the variable setup is completed (didn't error out on the first call)
    if [ ${BUILD_VAR_SETUP_COMPLETE} == "1" ]; then
        ################################################
        #########    Variable output section
        #########  don't need to update this section
        #########  unless you want to add/remove variables
        #########  to output
        echo""
        echo "**********************************"
        echo "********* ENV SETUP **************"
        echo ""
        echo "FIM Project:"
        echo "  OFS_PROJECT = ${OFS_PROJECT}"
        echo "  OFS_FIM     = ${OFS_FIM}"
        echo "  OFS_BOARD   = ${OFS_BOARD}"
        echo "  Q_PROJECT   = ${Q_PROJECT}"
        echo "  Q_REVISION  = ${Q_REVISION}"
        echo "  Fitter SEED = ${SEED}"
        echo "FME id"
        echo "  BITSTREAM_ID = ${BITSTREAM_ID}"
        echo "  BITSTREAM_MD = ${BITSTREAM_MD}"
        echo "Flow:"
        echo "  ENA_CREATE_WORK_DIR        = ${ENA_CREATE_WORK_DIR}"
        echo "  ENA_OPAE_SDK_SETUP_FOR_FIM = ${ENA_OPAE_SDK_SETUP_FOR_FIM}"
        echo "  ENA_PRE_COMPILE_SCRIPT     = ${ENA_PRE_COMPILE_SCRIPT}"
        echo "  ENA_SETUP_IP_LIB_SCRIPT    = ${ENA_SETUP_IP_LIB_SCRIPT}"
        echo "  ENA_FIM_COMPILE            = ${ENA_FIM_COMPILE}"
        echo "  ENA_PR_SETUP               = ${ENA_PR_SETUP}"
        echo "  ENA_USER_CLOCK_FOR_PR      = ${ENA_USER_CLOCK_FOR_PR}"
        echo "  ENA_POST_COMPILE_SCRIPT    = ${ENA_POST_COMPILE_SCRIPT}"
        echo "  ENA_FLASH                  = ${ENA_FLASH}"
        echo "  ENA_PR_BUILD_TEMPLATE_GEN  = ${ENA_PR_BUILD_TEMPLATE_GEN}"
        echo "  ENA_PRINT_TIMING_STATUS    = ${ENA_PRINT_TIMING_STATUS}"
        if [ ! -z ${PR_COMPILE} ]; then
            if [ ${PR_COMPILE} == "1" ]; then
                echo "PR project:"
                echo "  ENA_OPAE_SDK_SETUP_FOR_PR  = ${ENA_OPAE_SDK_SETUP_FOR_PR}"
                echo "  ENA_PR_COMPILE             = ${ENA_PR_COMPILE}"
                echo "  ENA_GBS_GENERATION         = ${ENA_GBS_GENERATION}"
                echo "  ENA_PR_USER_CLOCK_SETUP    = ${ENA_PR_USER_CLOCK_SETUP}"
            fi
        fi
        echo "OPAE_SDK:"
        echo "  OPAE_SDK_REPO = ${OPAE_SDK_REPO}"
        echo "  OPAE_SDK_REPO_BRANCH = ${OPAE_SDK_REPO_BRANCH}"
        echo "USER CLOCK:"
        echo "  USER_CLOCK_PATTERN = ${USER_CLOCK_PATTERN}"
        echo ""
        echo " path to work syn_top = $WORK_SYN_TOP_PATH"

        echo ""
        echo "File pointers:"
        echo "  BUILD_FIM_SH_FILE = ${BUILD_FIM_SH_FILE}"
        echo "  CREATE_WORK_DIR_SH_FILE = ${CREATE_WORK_DIR_SH_FILE}"
        echo "  FLOW_TCL_FILE = ${FLOW_TCL_FILE}"
        echo "  SETUP_TCL_FILE = ${SETUP_TCL_FILE}"
        echo "  FME_ID_MIF_FILE = ${FME_ID_MIF_FILE}"
        echo "  UPDATE_FME_IFC_ID_PY_FILE = ${UPDATE_FME_IFC_ID_PY_FILE}"

        echo "  WORK_FME_ID_MIF_FILE = ${WORK_FME_ID_MIF_FILE}"
        echo "  REPORT_TIMING_TCL_FILE = ${REPORT_TIMING_TCL_FILE}"
        echo "  WORK_BUILD_FLASH_SH_FILE = ${WORK_BUILD_FLASH_SH_FILE}"

        echo "  DISPLAY_TIMING_PASS_FAIL_SH_FILE = ${DISPLAY_TIMING_PASS_FAIL_SH_FILE}"
        echo "  WORK_PRE_COMPILE_SCRIPT_SH_FILE = ${WORK_PRE_COMPILE_SCRIPT_SH_FILE}"
        echo "  WORK_POST_COMPILE_SCRIPT_SH_FILE = ${WORK_POST_COMPILE_SCRIPT_SH_FILE}"
        echo "  BUILD_FIM_LOG_FILE = ${BUILD_FIM_LOG_FILE}"
        echo "  PR_SETUP_SH_FILE = ${PR_SETUP_SH_FILE}"
        echo "  CREATE_SDC_FOR_PR_COMPILE_TCL_FILE = ${CREATE_SDC_FOR_PR_COMPILE_TCL_FILE}"
        echo "  WORK_SDC_FOR_PR_COMPILE_SDC_FILE = ${WORK_SDC_FOR_PR_COMPILE_SDC_FILE}"
        echo "  FIX_PR_SDC_PY_FILE = ${FIX_PR_SDC_PY_FILE}"

        echo "  SETUP_USER_CLOCK_FOR_PR_TCL_FILE = ${SETUP_USER_CLOCK_FOR_PR_TCL_FILE}"
        echo "  IMPORT_USER_CLK_SDC_TCL_FILE = ${IMPORT_USER_CLK_SDC_TCL_FILE}"
        echo "  WORK_USER_CLOCK_DEFS_TCL_FILE = ${WORK_USER_CLOCK_DEFS_TCL_FILE}"
        echo "  SETUP_OPAE_SDK_SH_FILE = ${SETUP_OPAE_SDK_SH_FILE}"



        # exit as this will be the 2nd pass to just display the variables
        exit 0
    fi

fi


# check for required env variables
error=0
if [ -z ${OFS_ROOTDIR} ]; then
    echo "Error: OFS_ROOTDIR not set"
    error=1
fi

if [ -z ${WORK_DIR} ]; then
    echo "Error: WORK_DIR not set"
    error=1
fi

if [ "${error}" != "0" ]; then
    exit 1
fi
unset error

######################################################
######       Project variable section
######   edit variables to suit your project 

## for FME ID ROM MIF generation
#  HSSID - 2: Ethernet + PCIe, 1: PCIe only
#  VER_DEBUG - 1: debug version 0: normal version

# bitstream md
RESERVED_BITSTREAM_MD_VAL="000000000"
YEAR=$(date +"%y")
MONTH=$(date +"%m")
DAY=$(date +"%d")

# bitstream id
VER_DEBUG="0"
VER_MAJOR="4"
VER_MINOR="0"
VER_PATCH="1"
RESERVED_BITSTREAM_ID_VAL="000"
HSSI_ID="2"

# bitstream info
RESERVED_FIM_VARIANT_REVISION_VAL="00000000"
FIM_VARIANT_REVISION="00000001"


if [ -z ${OFS_BUILD_NUMBER} ]; then
    # use short git commit id for build number
    # can also use a number for OFS_BUILD_NUMBER < 8 digits long
    # if it's a number, auto zero extend is done below (in derived section)
    gitid="$(git log |head -1)"
    commit_id="${gitid#*commit }"
    OFS_BUILD_NUMBER="${commit_id:0:8}"
fi

if [ -z ${COPY_WORK} ]; then
    # set COPY_WORK default to '0'
    # 0: symlink files, 1: copy files to work directory
    COPY_WORK="0"
fi

## ofs_project, fim, board  are used to traverse directory
## e.g. ${WORK_DIR}/syn/${OFS_PROJECT}/${OFS_FIM}/${OFS_BOARD}/syn_top
# use "." or "" for empty 
# for D5005:
export OFS_PROJECT="d5005"
export OFS_FIM="."
export OFS_BOARD="."
# for agilex ac on devkit:
#export OFS_PROJECT="n6000"
#export OFS_FIM="base"
#export OFS_BOARD="agilex_f_dk"

# for Quartus scripts
# D5005
export Q_PROJECT="d5005"
export Q_REVISION="d5005"
# AC 
#export Q_PROJECT="ofs_top"
#export Q_REVISION="ofs_top"

# user clock node setup for specifying user clock to PR region (usually x1  and div 2 clocks)
# needs a single variable with wildcards to accommodate search by the setup_user_clock_for_pr.tcl
export USER_CLOCK_PATTERN="*iopll_0_clk*"  # sample name
#export USER_CLOCK_PATTERN="*qph_user_clk*"  #most likely the name when user clk is enabled

# repo location/branch variables used by SETUP_OPAE_SDK_SH_FILE
# These variables will override the defaults in that script
#export OPAE_SDK_REPO="https://github.com/OPAE/opae-sdk"
#export OPAE_SDK_REPO_BRANCH="master"


#### PR BUILD variables #####
# only set env variables only if it's not set
# allows user to pass in revisions/parittion name variables
# D5005
if [ -z ${Q_PR_REVISION} ]; then
    export Q_PR_REVISION="iofs_pr_afu"
fi
if [ -z ${Q_PR_PARTITION_NAME} ]; then
    export Q_PR_PARTITION_NAME="persona1"
fi


######################################
###  FIM Build flow

# 1: enable 
# 0: disable
# commenting or removing variable is the same as disable

# create work directory (this always need to be enabled, here only for custom build scripts)
export ENA_CREATE_WORK_DIR="1"
# setup OPAE SDK (for tools such as PACSign)
export ENA_OPAE_SDK_SETUP_FOR_FIM="0"
# optional pre-compile script
export ENA_PRE_COMPILE_SCRIPT="0"
#FUTURE_IMPROVEMENT:  setup IP_LIB script may be temporary (only for n6000 project)
export ENA_SETUP_IP_LIB_SCRIPT="0"
# Quartus compilation of FIM 
export ENA_FIM_COMPILE="1"
# enable  PR post compilation tasks
export ENA_PR_SETUP="1"
# enable user clock setup used in PR SETUP requires specification of user clock nodes 
export ENA_USER_CLOCK_FOR_PR="1"
# optional post-compile script
export ENA_POST_COMPILE_SCRIPT="0"
# create configuration flash image
export ENA_FLASH="1"
# enable creation of out-of-tree PR build environment
export ENA_PR_BUILD_TEMPLATE_GEN="1"
# print timing pass/fail message
export ENA_PRINT_TIMING_STATUS="1"



######################################
###  PR Build Flow

# 1: enable
# 0: disable
# commenting or removing variable is the same as disable
# setup OPAE SDK (for tools such as 'packager' for GBS creation and PACSign)
export ENA_OPAE_SDK_SETUP_FOR_PR="1"
export ENA_PR_COMPILE="1"
export ENA_GBS_GENERATION="1"
export ENA_PR_USER_CLOCK_SETUP="0"


###################################################
#####            Script path
#####     don't need to edit this unless using custom version of scripts
#####     naming convention:
#####         - directory paths variables should end with "_PATH"
#####         - files variables should end with "_<extension>_FILE" e.g. "_SH_FILE"
#####         - files pointers to files in the work directory should begin with "WORK_"

export SYN_TOP_PATH=${OFS_ROOTDIR}/syn/${OFS_PROJECT}/${OFS_FIM}/${OFS_BOARD}/syn_top
# WORK_SYN_TOP_PATH is used to copy qsf and other files to
export WORK_SYN_TOP_PATH=${WORK_DIR}/syn/${OFS_PROJECT}/${OFS_FIM}/${OFS_BOARD}/syn_top

# local path pointers
SYN_COMMON_SCRIPTS_PATH=${OFS_ROOTDIR}/scripts/common/syn
###############################################
#####   Script/file pointer

export BUILD_FIM_SH_FILE=${SYN_COMMON_SCRIPTS_PATH}/build_fim.sh
export CREATE_WORK_DIR_SH_FILE=${SYN_COMMON_SCRIPTS_PATH}/create_work_dir.sh
export FLOW_TCL_FILE=${SYN_COMMON_SCRIPTS_PATH}/flow.tcl
export SETUP_TCL_FILE=${SYN_COMMON_SCRIPTS_PATH}/setup.tcl
export FME_ID_MIF_FILE=${OFS_ROOTDIR}/src/ip/d5005/fme_id_rom/fme_id.mif
export UPDATE_FME_IFC_ID_PY_FILE=${SYN_COMMON_SCRIPTS_PATH}/update_fme_ifc_id.py
# FUTURE_IMPROVEMENT: D5005 points to fme_id_mif in the syn_top path (check to see if this can be removed)
export WORK_FME_ID_MIF_FILE=${WORK_SYN_TOP_PATH}/fme_id.mif
export REPORT_TIMING_TCL_FILE=${SYN_COMMON_SCRIPTS_PATH}/report_timing.tcl
export WORK_BUILD_FLASH_SH_FILE=${WORK_DIR}/syn/${OFS_PROJECT}/${OFS_FIM}/${OFS_BOARD}/scripts/build_flash/build_flash.sh
export DISPLAY_TIMING_PASS_FAIL_SH_FILE=${SYN_COMMON_SCRIPTS_PATH}/display_timing_pass_fail.sh
export WORK_PRE_COMPILE_SCRIPT_SH_FILE=${WORK_DIR}/syn/common/scripts/pre_compile_script.sh
export WORK_POST_COMPILE_SCRIPT_SH_FILE=${WORK_DIR}/syn/common/scripts/post_compile_script.sh
export BUILD_FIM_LOG_FILE=${OFS_ROOTDIR}/build_fim_$(basename ${WORK_DIR}).log
# FUTURE_IMPROVEMENT:temporary fix for n6000 (remove once qsf and design_files.tcl points to the correct IP/IPSS dir.
export WORK_SETUP_IP_LIB_SH_FILE=${WORK_DIR}/syn/common/scripts/setup_ip_lib.sh

#### for PR setup FIM compile- script/file pointer
export PR_SETUP_SH_FILE=${SYN_COMMON_SCRIPTS_PATH}/pr_setup.sh
export CREATE_SDC_FOR_PR_COMPILE_TCL_FILE=${SYN_COMMON_SCRIPTS_PATH}/create_sdc_for_pr_compile.tcl
# output that combines static region sdc constraints from the FIM compile to one output sdc file for use in PR compile
export WORK_SDC_FOR_PR_COMPILE_SDC_FILE=${WORK_SYN_TOP_PATH}/${Q_PROJECT}.out.sdc
export FIX_PR_SDC_PY_FILE=${SYN_COMMON_SCRIPTS_PATH}/fix_pr_sdc.py

# user clock scripts
# SETUP_USER_CLOCK_FOR_PR_TCL_FILE is the top script
export SETUP_USER_CLOCK_FOR_PR_TCL_FILE=${SYN_COMMON_SCRIPTS_PATH}/setup_user_clock_for_pr.tcl
export IMPORT_USER_CLK_SDC_TCL_FILE=${SYN_COMMON_SCRIPTS_PATH}/import_user_clk_sdc.tcl
# this is an output file which defines the user clock
export WORK_USER_CLOCK_DEFS_TCL_FILE=${WORK_SYN_TOP_PATH}/ofs_partial_reconfig/user_clock_defs.tcl

# for opae-sdk repo builds (note that this matches the defaults in setup_opae-sdk.sh)
#  commenting most this section out as the defaults have the same settings
#  uncomment and modify if the file/directory lcoations change 
export SETUP_OPAE_SDK_SH_FILE="${SYN_COMMON_SCRIPTS_PATH}/setup_opae_sdk.sh"

#### PR file pointers ****
export WORK_PR_JSON_FILE="${WORK_SYN_TOP_PATH}/${Q_PR_REVISION}.json"
export WORK_PR_RBF_FILE="${WORK_SYN_TOP_PATH}/output_files/${Q_PR_REVISION}.${Q_PR_PARTITION_NAME}.rbf"
export WORK_PR_GBS_FILE="${WORK_SYN_TOP_PATH}/output_files/${Q_PR_REVISION}.${Q_PR_PARTITION_NAME}.gbs"
export WORK_PR_PACSIGN_GBS_FILE="${WORK_SYN_TOP_PATH}/output_files/${Q_PR_REVISION}.${Q_PR_PARTITION_NAME}_unsigned.gbs"


#FUTURE_IMPROVEMENT: add capabilities to specify project only work directory so create_work_dir.sh
#      will only sync over the pertnant files to <WORK_DIR>. 
#      currently create_work_dir.sh grabs the whole ofs-dev repo including other projects
#      will need to modify create_work_dir.sh to consume the project only source, IPs, and syn (probably verification also)


####################################################
########          Derived variable section
########      * Don't need to edit this section *
########        unless you want a different
########        variable format

# SEED may be set by the user.  if so, use that SEED as that will be changed in qsf of the associated WORK_DIR
# else, get the default SEED value in the qsf file
if [ -z ${SEED} ]; then
    export SEED=$(sed -r '/set_global_assignment.*SEED/ ! d; s/.*[[:space:]]+([0-9]+)[[:space:]]*$/\1/; q' ${SYN_TOP_PATH}/${Q_PROJECT}.qsf)

    if [ "${SEED}" == "" ]; then
        echo "Error: cannot get SEED from ${SYN_TOP_PATH}/${Q_PROJECT}.qsf"
        exit 1
    fi
fi

# only get the lowest character as the register only has allocation for 1 char
SEED_LSD=${SEED: -1}

# Build number field is 8 characters long, extending zeros if digit, else, the string should be 8 characters long
# replacing extended pattern match construct to be compatible with older bash version
#if [[ ${OFS_BUILD_NUMBER} == ?(-)+([0-9]) ]]; then
if echo "${OFS_BUILD_NUMBER}" | grep -qE '^[0-9]+$'; then
    # is number, so extend 0's
    printf -v BUILD_NUMBER "%08d" ${OFS_BUILD_NUMBER}
else
    BUILD_NUMBER=${OFS_BUILD_NUMBER}
fi

# these variables used by update_fme_ifc_id.py script
export BITSTREAM_MD=${RESERVED_BITSTREAM_MD_VAL}${YEAR}${MONTH}${DAY}${SEED_LSD}
export BITSTREAM_ID=${VER_DEBUG}${VER_MAJOR}${VER_MINOR}${VER_PATCH}${RESERVED_BITSTREAM_ID_VAL}${HSSI_ID}${BUILD_NUMBER}
export BITSTREAM_INFO=${RESERVED_FIM_VARIANT_REVISION_VAL}${FIM_VARIANT_REVISION}



# test len of bitstream ID and MD to ensure it's under 16. need to match with register size in the FIM
# print index to help identify format error
if [ "${#BITSTREAM_ID}" != "16" ]; then
    echo "Error: BITSTREAM_ID must be 16 characters long, but is ${#BITSTREAM_ID}"
    echo "       Index        = 0123456789012345"
    echo "       BITSTREAM_ID = $BITSTREAM_ID"
    exit 1
fi

if [ "${#BITSTREAM_MD}" != "16" ]; then
    echo "Error: BITSTREAM_MD must be 16 characters long, but is ${#BITSTREAM_MD}"
    echo "       Index        = 0123456789012345"
    echo "       BITSTREAM_MD = $BITSTREAM_MD"
    exit 1
fi



# This variable is set when there are no errors
# indicates that the build variables are setup correctly and build can be started
export BUILD_VAR_SETUP_COMPLETE="1"

