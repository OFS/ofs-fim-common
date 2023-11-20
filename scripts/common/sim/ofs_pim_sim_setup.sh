#!/bin/bash
# Copyright 2021 Intel Corporation
# SPDX-License-Identifier: MIT

set -e

usage() {
  echo "Usage: $0 -t <tgt dir> [-b <board name>] [-r <platform template root>] [-f <FIM variant>] <filelist.txt>" 1>&2
  echo "" 1>&2
  echo "  This script will configure a simulation environment by constructing a PIM" 1>&2
  echo "  instance. It maps board name and FIM variant to a PIM configuration file" 1>&2
  echo "  and invokes the scripts required to build the platform-specific PIM" 1>&2
  echo "" 1>&2
  echo "  If -r is specified, it should point to an existing PIM template tree." 1>&2
  echo "  If -r is not specified, a new PIM template tree will be constructed" 1>&2
  echo "  in <tgt dir>/hw. The board name is not required when -r is set." 1>&2
  echo "" 1>&2
  echo "  The AFU specified in filelist.txt is also instantiated." 1>&2
  echo "" 1>&2
  echo "  Simulators should then import the configured PIM and AFU with:" 1>&2
  echo "    -F <tgt dir>/all_sim_files.list" 1>&2
  echo "  Upper case \"F\" must be used in order to follow relative paths" 1>&2
  echo "  inside all_sim_files.list!" 1>&2

  exit 1
}

PIM_ROOT_DIR=""
BOARD_NAME=""
PLATFORM_TEMPLATE=""
FIM_VARIANT="base"

while getopts "t:b:r:f:" OP; do
  case "${OP}" in
    t)
      PIM_ROOT_DIR="${OPTARG}"
      ;;
    b)
      BOARD_NAME="${OPTARG}"
      ;;
    r)
      PLATFORM_TEMPLATE="${OPTARG}"
      ;;
    f)
      FIM_VARIANT="${OPTARG}"
      ;;
    ?)
      echo "" 1>&2
      usage
      ;;
  esac
done
shift $((OPTIND-1))

AFU_FILELIST="${1}"

if [ "${PIM_ROOT_DIR}" == "" ]; then
  echo "Target directory not specified!" 1>&2
  echo "" 1>&2
  usage
fi
if [[ -z "${BOARD_NAME}" && -z "${PLATFORM_TEMPLATE}" ]]; then
  echo "Board name not specified!" 1>&2
  echo "" 1>&2
  usage
fi
if [ "${FIM_VARIANT}" == "" ]; then
  echo "FIM variant not specified!" 1>&2
  echo "" 1>&2
  usage
fi


case "${BOARD_NAME}" in
  adp)
    PIM_PLATFORM_NAME=ofs_agilex_adp
    PIM_INI_FILE="${OFS_ROOTDIR}"/src/top/ofs_agilex_adp.ini
    PIM_AFU_MAIN="${OFS_ROOTDIR}"/ofs-common/src/fpga_family/agilex/port_gasket/afu_main_pim/afu_main.sv
    ;;
  agilex_f_dk)
    PIM_PLATFORM_NAME=ofs_agilex_f_dk
    PIM_INI_FILE="${OFS_ROOTDIR}"/src/fims/n6000/agilex_f_dk/ofs_agilex_f_dk.ini
    PIM_AFU_MAIN="${OFS_ROOTDIR}"/src/port_gasket/agilex/afu_main_pim/afu_main.sv
    ;;
  d5005)
    PIM_PLATFORM_NAME=ofs_d5005
    PIM_INI_FILE="${OFS_ROOTDIR}"/src/top/ofs_d5005.ini
    PIM_AFU_MAIN="${OFS_ROOTDIR}"/ofs-common/src/fpga_family/stratix10/port_gasket/afu_main_pim/afu_main.sv
    ;;
  "")
    PIM_PLATFORM_NAME=
    PIM_INI_FILE=
    PIM_AFU_MAIN=
    ;;
  *)
    echo "Unknown board name: ${BOARD_NAME}" 1>&2
    exit 1
esac


rm -rf "${PIM_ROOT_DIR}"
mkdir -p "${PIM_ROOT_DIR}"

if [ -z "${PLATFORM_TEMPLATE}" ]; then
  source "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/setup_opae_sdk.sh

  # Find the PIM source repository
  if [ -z "${OFS_PLATFORM_AFU_BBB}" ]; then
    source "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/pim/setup_ofs_platform_afu_bbb.sh
  else
    echo "Using provided OFS_PLATFORM_AFU_BBB=${OFS_PLATFORM_AFU_BBB}"
  fi

  # Generate the PIM for the target platform
  $OFS_ROOTDIR/ofs-common/scripts/common/syn/pim/ofs_pim_setup.sh -t "${PIM_ROOT_DIR}" -n "${PIM_PLATFORM_NAME}" -i "${PIM_INI_FILE}"
  PLATFORM_TEMPLATE="${PIM_ROOT_DIR}"

  # Generate a configured PIM instance that can be loaded into the simulator
  mkdir "${PIM_ROOT_DIR}"/pim_instance
  env OPAE_PLATFORM_ROOT="${PLATFORM_TEMPLATE}" afu_platform_config -t "${PIM_ROOT_DIR}"/pim_instance -i ofs_plat_afu --sim ${PIM_PLATFORM_NAME}

  # Create a top-level simulator script that imports the PIM sources.
  cat > "${PIM_ROOT_DIR}"/pim_source_files.list <<EOF
+incdir+pim_instance
-F pim_instance/platform_if_includes.txt
-F pim_instance/platform_if_addenda.txt
EOF
fi

if [ ! -z "${AFU_FILELIST}" ]; then
  echo "Configuring AFU ${AFU_FILELIST}"

  # Construct the AFU simulation environment
  if [ -z "${PIM_PLATFORM_NAME}" ]; then
    $OFS_ROOTDIR/ofs-common/scripts/common/sim/afu_ofs_plat_filelist.sh -t "${PIM_ROOT_DIR}" -r "${PLATFORM_TEMPLATE}" "${AFU_FILELIST}"
  else
    $OFS_ROOTDIR/ofs-common/scripts/common/sim/afu_ofs_plat_filelist.sh -t "${PIM_ROOT_DIR}" -n "${PIM_PLATFORM_NAME}" -r "${PLATFORM_TEMPLATE}" "${AFU_FILELIST}"
  fi

  # Use the PIM version of afu_main.sv
  if [ -f "${PIM_ROOT_DIR}"/afu_sim_files.list ]; then
    echo $PIM_AFU_MAIN >> "${PIM_ROOT_DIR}"/afu_sim_files.list
  fi
fi
