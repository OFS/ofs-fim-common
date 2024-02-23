#!/bin/bash
# Copyright 2020-2023 Intel Corporation
# SPDX-License-Identifier: MIT

usage() {
  echo "Usage: $(basename $0) [-k] [-p] [--stage=<action>] [--ofss=<IP config>] <build target> [<work dir name>]" 1>&2
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
  echo "  When -p is set and the FIM supports partial reconfiguration, a PR" 1>&2
  echo "  template tree is generated at the end of the FIM build. The PR template" 1>&2
  echo "  tree is located in the top of the work directory but is relocatable" 1>&2
  echo "  and uses only relative paths. See syn/common/scripts/generate_pr_release.sh" 1>&2
  echo "  for details." 1>&2
  echo "" 1>&2
  echo "  The --stage option controls which portion of the OFS build is run:" 1>&2
  echo "    all     - Run all build stages (default)." 1>&2
  echo "    setup   - Initialize a project in the work directory." 1>&2
  echo "    compile - Run the Quartus compilation flow on a project that was already" 1>&2
  echo "              initialized with \"setup\"." 1>&2
  echo "    finish  - Complete OFS post-compilation tasks, such as generating flash" 1>&2
  echo "              images and, if -p is set, generating a release." 1>&2
  echo "" 1>&2
  echo "  Set the --ofss option to modify IP, such as the PCIe SS, using an .ofss" 1>&2
  echo "  configuration file. This parameter is consumed during the setup stage and" 1>&2
  echo "  IP is updated only inside the work tree. More than one .ofss file may be" 1>&2
  echo "  passed to the --ofss switch by concatenating them separated by commas." 1>&2
  echo "  For example: \"--ofss config_a.ofss,config_b.ofss\"." 1>&2
  echo "" 1>&2
  echo "  The -e option runs only Quartus analysis and elaboration. It completes the" 1>&2
  echo "  \"setup\" stage, passes \"-end synthesis\" to the Quartus compilation flow" 1>&2
  echo "  and exits without running the \"finish\" stage." 1>&2
  echo "" 1>&2
  exit 1
}

ANALYSIS_AND_ELAB_ONLY=""
KEEP_WORK_ARG=""
DO_PR_BUILD_TEMPLATE_GEN=""
STAGE="all"
OFSS_CONFIG_SCRIPT=""
ORIG_COMMAND_LINE=( "$0" "$@" )

while getopts "ekp-:" OP; do
    case "${OP}" in
      -)
        # Process long arguments
        case "${OPTARG}" in
          stage)
            STAGE="${!OPTIND}"; OPTIND=$(($OPTIND + 1))
            ;;
          stage=*)
            STAGE=${OPTARG#*=}
            ;;
          ofss)
            OFSS_CONFIG_SCRIPT="${!OPTIND}"; OPTIND=$(($OPTIND + 1))
            ;;
          ofss=*)
            OFSS_CONFIG_SCRIPT=${OPTARG#*=}
            ;;
          *)
            if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                echo "Unknown option --${OPTARG}" >&2
                echo "" >&2
                usage
            fi
            ;;
        esac
        ;;
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
        echo "" >&2
        usage
        ;;
    esac
done
shift $((OPTIND-1))

# Convert STAGE to lower case
STAGE=$(echo $STAGE | tr '[:upper:]' '[:lower:]')

export ANALYSIS_AND_ELAB_ONLY
export KEEP_WORK_ARG
export DO_PR_BUILD_TEMPLATE_GEN

if [ ! -z "${OFSS_CONFIG_SCRIPT}" ]; then
    export USE_OFSS_CONFIG_SCRIPT=${OFSS_CONFIG_SCRIPT}
fi

if [ -z "${1}" ]; then
    echo "Error: no build target." >&2
    echo "" >&2
    usage
fi


#############################################
#### Check for $OFS_ROOTDIR and set to cloned repo toplevel path
if [ -z "${OFS_ROOTDIR}" ]; then
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

#################################
###   Set WORK directory
###   checks on WORK directory done in work dir creation script
if [ -z "${2}" ]; then
    export WORK_DIR="${OFS_ROOTDIR}/work"
else
    if [ "$(dirname ${2})" == "." ]; then
        # Passing in a name, prepend OFS_ROOTDIR to the path
        export WORK_DIR="${OFS_ROOTDIR}/${2}"
    else
        # Passing in a path, us as-is
        export WORK_DIR="${2}"
    fi
fi

#################################
#### launch build script

BUILD_FIM_LOG_FILE="${OFS_ROOTDIR}"/build_fim_$(basename "${WORK_DIR}").log

# Note: "set -o pipefail" is needed to catch a nonzero exit code from
# the build script.
set -o pipefail

## Passing "-i" to tee means it should finish reading/writing all data from the
## input pipe even if it receives SIGINT itself (i.e. ^C on console).

if [ "$STAGE" == "all" ]; then
    CMD=build_fim.sh
elif [ "$STAGE" == "setup" ]; then
    CMD=build_fim_setup.sh
elif [ "$STAGE" == "compile" ]; then
    CMD=build_fim_compile.sh
elif [ "$STAGE" == "finish" ]; then
    CMD=build_fim_finish.sh
else
    echo "Error: incorrect stage: $STAGE. Most be one of all, setup, compile or finish."
    exit 1
fi

{
  echo 'build_top.sh launched using command line:'
  printf ' %s' "${ORIG_COMMAND_LINE[@]}"; echo
  echo
  echo "Proceeding with requested build script $CMD..."
} >"$BUILD_FIM_LOG_FILE"

"${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/${CMD} "$1" "$WORK_DIR" 2>&1|tee -a -i "${BUILD_FIM_LOG_FILE}"
error_code=${?}
if [ "${error_code}" != "0" ]; then
    echo "Error running ${OFS_ROOTDIR}/ofs-common/scripts/common/syn/${CMD}" 1>&2
    echo "Exit code: ${error_code}" 1>&2
    exit 1
fi
set +o pipefail
