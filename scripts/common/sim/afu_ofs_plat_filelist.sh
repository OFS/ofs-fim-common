#!/bin/bash
# Copyright 2021 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Prepare an AFU for simulation, given an instance of the PIM and an AFU
## file list.
##
## ofs_pim_setup.sh, which builds the PIM, must be run before this script.
##

set -e

usage() {
  echo "Usage: $0 -t <tgt dir> -n <platform name> -r <platform template root> <filelist.txt>" 1>&2
  exit 1
}

TGT=""
PLATFORM_NAME=""
PLATFORM_TEMPLATE=""

while getopts "t:n:r:" OP; do
  case "${OP}" in
    t)
      TGT="${OPTARG}"
      ;;
    n)
      PLATFORM_NAME="${OPTARG}"
      ;;
    r)
      PLATFORM_TEMPLATE="${OPTARG}"
      ;;
    ?)
      echo "" 1>&2
      usage
      ;;
  esac
done
shift $((OPTIND-1))

AFU_FILELIST="${1}"
if [ "$AFU_FILELIST" == "" ]; then
  usage
fi

AFU_FILELIST=`readlink -ve ${1}`

if [ "${TGT}" == "" ]; then
  echo "Target directory not specified!" 1>&2
  echo "" 1>&2
  usage
fi
if [ "${PLATFORM_NAME}" == "" ]; then
  echo "Platform name not specified!" 1>&2
  echo "" 1>&2
  usage
fi
if [ "${PLATFORM_TEMPLATE}" == "" ]; then
  echo "Platform template root directory not specified!" 1>&2
  echo "" 1>&2
  usage
fi
echo $TGT
echo $PLATFORM_NAME
echo $AFU_FILELIST

# Construct the AFU simulation tree in ${TGT}/afu using afu_sim_setup from the
# OPAE SDK. Platform Designer IP will be generated for simulation within the
# "afu" tree. afu_sim_setup will also create simulator scripts for loading the
# AFU and the PIM.
(cd "${TGT}"
 rm -rf afu
 env OPAE_PLATFORM_ROOT=${PLATFORM_TEMPLATE} afu_sim_setup --platform=${PLATFORM_NAME} -s "${AFU_FILELIST}" afu
)

# If AFU sources are specified, provide a wrapper for loading them.
if [ -f "${TGT}"/afu/vlog_files.list ]; then
  cat > ${TGT}/afu_sim_files.list <<EOF
+incdir+afu/rtl
-F afu/vlog_files.list
EOF
fi
