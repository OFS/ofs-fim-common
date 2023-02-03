#!/bin/bash

usage() {
  echo "Usage: $0 [-k] [-p] <build target> [<work dir name>]" 1>&2
  echo "" 1>&2
  echo "  Build a FIM instance specified by <build target>. The target names" 1>&2
  echo "  an FPGA architecture, board and configuration." 1>&2
  echo "" 1>&2
  echo "  The FIM is built in <work dir name>. If not specified, the target is" 1>&2
  echo "  \${OFS_ROOTDIR}/work." 1>&2
  echo "" 1>&2
  echo "  The -k option preserves and rebuilds within an existing work tree" 1>&2
  echo "  instead of overwriting it." 1>&2
  echo "" 1>&2
  echo "  When -p is set, if the FIM is able then a partial reconfiguration" 1>&2
  echo "  template tree is generated at the end of the FIM build. The PR template" 1>&2
  echo "  tree is located in the top of the work directory but is relocatable" 1>&2
  echo "  and uses only relative paths. See syn/common/scripts/generate_pr_release.sh" 1>&2
  echo "  for details." 1>&2
  echo "" 1>&2
  echo "  The -e option runs only Quartus analysis and elaboration." 1>&2
  exit 1
}

ANALYSIS_AND_ELAB_ONLY=""
KEEP_WORK_ARG=""
DO_PR_BUILD_TEMPLATE_GEN=""

while getopts "ekp" OP; do
  case "${OP}" in
    e)
      ANALYSIS_AND_ELAB_ONLY=1
      ;;
    k)
      KEEP_WORK_ARG="-k"
      ;;
    p)
      DO_PR_BUILD_TEMPLATE_GEN=1
      ;;
    ?)
      echo "" 1>&2
      usage
      ;;
  esac
done
shift $((OPTIND-1))

export ANALYSIS_AND_ELAB_ONLY
export KEEP_WORK_ARG
export DO_PR_BUILD_TEMPLATE_GEN

if [ -z "${1}" ]; then
    echo "Error: no build target." 1>&2
    echo "" 1>&2
    usage
fi


#############################################
#### Check for $OFS_ROOTDIR and set to cloned repo toplevel path
echo $OFS_ROOTDIR
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


#############################################
#### Setup pointer to platform-specific setup

# Remove the optional trailing colon and variant string.
export OFS_BOARD_PATH="${1%%:*}"
echo ">>> OFS Board Path = ${OFS_BOARD_PATH}"
if [ ! -d "${OFS_ROOTDIR}/syn" ]; then
    echo "OFS platform path ${OFS_ROOTDIR}/syn not found"
    exit 1
fi

# Retain the core board product that is being targeted for compilation
OFS_BOARD_CORE="${1#*syn\/}"
export OFS_BOARD_CORE="${OFS_BOARD_CORE%%\/*}"
echo ">>> OFS Board Core = ${OFS_BOARD_CORE}"

# Extract the variant string (which includes leading colon), then remove the
# leading colon. If no variant was specified, this results in an empty string.
OFS_BOARD_VARIANT="${1#$OFS_BOARD_PATH}"
OFS_BOARD_VARIANT="${OFS_BOARD_VARIANT#:}"
# No sanity checking of the value can be done at this point. It's up to the
# board-specific handling scripts to use or abuse the value as they want.
export OFS_BOARD_VARIANT

# Split the variant string into comma-delimited components. These are then
# converted into build "tags" which can be used later through a corresponding
# environment variable.  The primary use is for simple boolean flags, with the
# tag variable not set meaning 'false' and tag variable set to "1" for true.
#
# A tag may optionally accept a string value which is exported in its tag
# variable rather than using the default value of "1".
#
# Example results:
#
#   syn/build_top.sh n6000/base_x16/adp =>
#     (no $OFS_BUILD_TAG_* variables exported)
#
#   syn/build_top.sh n6000/base_x16/adp:flat =>
#     OFS_BUILD_TAG_FLAT=1
#
#   syn/build_top.sh n6000/base_x16/adp:no_hssi,signaltap=path/to/some.stp =>
#     OFS_BUILD_TAG_NO_HSSI=1
#     OFS_BUILD_TAG_SIGNALTAP=path/to/some.stp
#
IFS=, read -r -a _OFS_BUILD_TAGS <<< "$OFS_BOARD_VARIANT"
for t in "${_OFS_BUILD_TAGS[@]}"; do
    # Everything up to the first '=' character is the tag's name.
    _tag_key="${t%%=*}"
    # Anything following the tag name and '=' should be the value.
    _tag_value="${t#$_tag_key}"
    _tag_value="${_tag_value#=}"

    # Make the key upper-case to normalize the variable name, then set it to
    # "1" for the usual case of string not provided on command line.
    export "OFS_BUILD_TAG_${_tag_key^^}=${_tag_value:-1}"
done
unset _OFS_BUILD_TAGS _tag_key _tag_value

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


######################################
####   source build variable script
####   need to have WORK_DIR set before running this script

source "${OFS_ROOTDIR}/ofs-common/scripts/common/syn/build_setup.sh"


if [ -z "${BUILD_FIM_SH_FILE}" ]; then 
    echo "Error: BUILD_FIM_SH_FILE variable not set" 1>&2
    echo "Variable should be set in build variable setup script" 1>&2
    exit 1
else
    if [ ! -e ${BUILD_FIM_SH_FILE} ]; then
        echo "Error: Cannot find ${BUILD_FIM_SH_FILE}" 1>&2
        exit 1
    fi
fi


#################################
#### launch build script

rm -f ${BUILD_FIM_LOG_FILE}
touch ${BUILD_FIM_LOG_FILE}

# source build var setup file again to print out env variables to log file
source "${OFS_ROOTDIR}/ofs-common/scripts/common/syn/build_setup.sh" 2>&1|tee -a ${BUILD_FIM_LOG_FILE}

# Launch build_fim.sh script

# Note: "set -o pipefail" is needed to catch a nonzero exit code from
# execution of $BUILD_FIM_SH_FILE in below pipeline.
set -o pipefail
# Passing "-i" to tee means it should finish reading/writing all data from the
# input pipe even if it receives SIGINT itself (i.e. ^C on console).
${BUILD_FIM_SH_FILE} 2>&1|tee -i -a ${BUILD_FIM_LOG_FILE}
error_code=${?}
if [ "${error_code}" != "0" ]; then
    echo "Error running ${BUILD_FIM_SH_FILE}" 1>&2
    echo "Exit code: ${error_code}" 1>&2
    exit 1
fi
set +o pipefail
