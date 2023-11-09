#!/bin/bash
# Copyright (C) 2021-2022 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Configure a FIM or in-tree PR build for an AFU that uses the Platform Interface
## Manager.
##
## The following environment variables are expected:
##
##  AFU_WITH_PIM      - When set, the path to an AFU filelist.txt holding the list
##                      of AFU sources. When not set, don't use the PIM.
##  PIM_ROOT_DIR      - Directory where Quartus will find the PIM and AFU sources.
##  PIM_PLATFORM_NAME - Name of the platform
##  PIM_INI_FILE      - PIM .ini file describing the platform
##

SCRIPTNAME="$(basename -- "$0")"
SCRIPT_DIR="$(cd "$(dirname -- "$0")" 2>/dev/null && pwd -P)"

usage() {
  echo "" 1>&2
  echo "Usage: $0 [-s]" 1>&2
  echo "" 1>&2
  echo "  If the proper environment variables needed to configure the Platform" 1>&2
  echo "  Interface Manager are defined, then instantiate the PIM." 1>&2
  echo "" 1>&2
  echo "  When -s (safe mode) is set, return 0 if any of the required environment" 1>&2
  echo "  variables is not set." 1>&2
  echo "" 1>&2
  exit 1
}

NOT_SAFE_MODE=1

while getopts "s" OP; do
  case "${OP}" in
    s)
      NOT_SAFE_MODE=0
      ;;
    ?)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if [ "X${PIM_ROOT_DIR}" == "X" ]; then
    echo "ofs_pim_and_afu_config.sh: PIM_ROOT_DIR is not defined!"
    exit ${NOT_SAFE_MODE}
fi
if [ "X${PIM_PLATFORM_NAME}" == "X" ]; then
    echo "ofs_pim_and_afu_config.sh: PIM_PLATFORM_NAME is not defined!"
    exit ${NOT_SAFE_MODE}
fi
if [ "X${PIM_INI_FILE}" == "X" ]; then
    echo "ofs_pim_and_afu_config.sh: PIM_INI_FILE is not defined!"
    exit ${NOT_SAFE_MODE}
fi

set -e
rm -rf "${PIM_ROOT_DIR}"
"${SCRIPT_DIR}"/ofs_pim_setup.sh -t "${PIM_ROOT_DIR}"/pim_template -n "${PIM_PLATFORM_NAME}" -i "${PIM_INI_FILE}"

AFU_FILELIST="${AFU_WITH_PIM}"
if [ "X${AFU_FILELIST}" == "X" ]; then
    # No PIM-wrapped AFU requested. Use a dummy to set up the environment.
    AFU_FILELIST="${SCRIPT_DIR}"/dummy_afu/dummy_afu_files.txt
fi

# Construct the AFU synthesis script in ${PIM_ROOT_DIR} using afu_synth_setup
# from the OPAE SDK.
echo "PIM_ROOT_DIR = $PIM_ROOT_DIR"
set -x
(cd "${PIM_ROOT_DIR}"
 env OPAE_PLATFORM_ROOT="${PWD}"/pim_template afu_synth_setup --platform=${PLATFORM_NAME} -s "${AFU_FILELIST}" afu
)
set +x

cat > "${PIM_ROOT_DIR}"/README <<EOF
This tree was created by ${SCRIPT_DIR}/${SCRIPTNAME}.

It contains:

- pim_template, an instance of the Platform Interface Manager specific to the
  FIM topology. For details, see pim_template/README. This template is used
  to construct the afu tree.

- afu, a tree holding PIM sources derived from pim_template. The PIM sources
  are added to the build by loading pim.tcl.

- pim.tcl, which loads the PIM into a Quartus build.
EOF

cat > "${PIM_ROOT_DIR}"/pim.tcl <<EOF
# Import the PIM
set_global_assignment -name SEARCH_PATH afu_with_pim/afu/build/platform
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE afu_with_pim/afu/build/platform/platform_if_addenda.qsf
EOF

if [ "X${AFU_WITH_PIM}" != "X" ]; then
    cat >> "${PIM_ROOT_DIR}"/README <<EOF

- afu.tcl, which loads the AFU defined in ${AFU_WITH_PIM}.
EOF

    cat > "${PIM_ROOT_DIR}"/afu.tcl <<EOF
# Import the AFU
set_global_assignment -name SEARCH_PATH afu_with_pim/afu/hw
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE afu_with_pim/afu/hw/afu.qsf
EOF
fi
