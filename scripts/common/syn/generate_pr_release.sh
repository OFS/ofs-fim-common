#!/bin/bash
# Copyright (C) 2021-2023 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Given a FIM base build, generate a "release" tree for PR builds. The release
## tree includes the Platform Interface Manager (PIM). The generated tree structure
## is compatible with the OPAE SDK AFU composition tools: afu_synth_setup and
## afu_sim_setup. Set the OPAE_PLATFORM_ROOT environment variable to the root
## of the tree.
##

SCRIPTNAME="$(basename -- "$0")"
SCRIPT_DIR="$(cd "$(dirname -- "$0")" 2>/dev/null && pwd -P)"

usage() {
  echo "Usage: $0 -t <tgt dir> [-f] <build target> <work dir name>" 1>&2
  echo "" 1>&2
  echo "  Given the build target and work directory of a completed FIM build," 1>&2
  echo "  generate a PR build template tree at tgt dir. The template tree may" 1>&2
  echo "  be used with the OPAE SDK tools afu_synth_setup and afu_sim_setup" 1>&2
  echo "  by setting the environment variable OPAE_PLATFORM_ROOT to the target." 1>&2
  echo "" 1>&2
  echo "  The generated build tree includes the Platform Interface Manager." 1>&2
  echo "" 1>&2
  echo "  If tgt dir exists, the script will abort unless -f is specified." 1>&2
  exit 1
}

FORCE="0"
TGT=""

while getopts "ft:" OP; do
  case "${OP}" in
    f)
      FORCE=1
      ;;
    t)
      TGT="${OPTARG}"
      ;;
    ?)
      echo "" 1>&2
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if [ "${TGT}" == "" ]; then
    echo "Target directory not specified!" 1>&2
    echo "" 1>&2
    usage
fi

if [ -e "${TGT}" ]; then
    if [ "${FORCE}" == "0" ]; then
        echo "Target directory ${TGT} exists" 1>&2
        exit 1
    fi
fi

# Set to indicate the OPAE platform release tree is being generated. The
# OPAE_PLATFORM_GEN environment variable configures source file selection
# in Quartus .tcl files.
export OPAE_PLATFORM_GEN=1
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
    usage
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

# Remove the optional trailing colon and variant string.
export OFS_BOARD_PATH="${1%%:*}"
#if [ ! -d "${OFS_ROOTDIR}/syn/${OFS_BOARD_PATH}" ]; then
#    echo "OFS platform path ${OFS_ROOTDIR}/syn/${OFS_BOARD_PATH} not found"
#    exit 1
#fi

# Extract the variant string (which includes leading colon), then remove the
# leading colon. If no variant was specified, this results in an empty string.
OFS_BOARD_VARIANT="${1#$OFS_BOARD_PATH}"
OFS_BOARD_VARIANT="${OFS_BOARD_VARIANT#:}"
export OFS_BOARD_VARIANT

if [ "X${BUILD_VAR_SETUP_COMPLETE}" == "X" ]; then
    source "${OFS_ROOTDIR}/ofs-common/scripts/common/syn/build_var_setup_common.sh"
    chk_exit_code "source ${OFS_ROOTDIR}/ofs-common/scripts/common/syn/build_var_setup_common.sh"
    # run the 2nd time to display the env variable
    "${OFS_ROOTDIR}/ofs-common/scripts/common/syn/build_var_setup_common.sh"
else
    # if BUILD_VAR_SETUP_COMPLETE is defined build_var_setup.sh has completed
    # run one more time to display env variables
    "${OFS_ROOTDIR}/ofs-common/scripts/common/syn/build_var_setup_common.sh"
    chk_exit_code "source ${OFS_ROOTDIR}/ofs-common/scripts/common/syn/build_var_setup_common.sh"
fi


###############################
###     OFS PIM setup
###

if [ -z "${OFS_PLATFORM_AFU_BBB}" ]; then
    source "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/pim/setup_ofs_platform_afu_bbb.sh
else
    echo "Using provided OFS_PLATFORM_AFU_BBB=${OFS_PLATFORM_AFU_BBB}"
fi

if [ ! -d "${OFS_PLATFORM_AFU_BBB}"/plat_if_develop ]; then
  echo "\$OFS_PLATFORM_AFU_BBB doesn't look like a clone of https://github.com/OFS/ofs-platform-afu-bbb"
  exit 1
fi


###########################################################################
##
## Done with the preamble. Now construct the PR release tree.
##
###########################################################################

if [ ! -d "${WORK_SYN_TOP_PATH}" ]; then
    echo "Error: FIM build not found at ${WORK_SYN_TOP_PATH}"
    exit 1
fi
if [ ! -f ${WORK_SYN_TOP_PATH}/output_files/${Q_PROJECT}.sof ]; then
    echo "Error: FIM .sof not found at ${WORK_SYN_TOP_PATH}/output_files/${Q_PROJECT}.sof"
    exit 1
fi

set -e
set -x

rm -rf "${TGT}"
mkdir -p "${TGT}"
# Change TGT to an absolute path
TGT=$(cd "${TGT}"; pwd)

# Add some standard scripts (afu_synth and update_pim)
mkdir -p "${TGT}"/bin
cp -L "${SCRIPT_DIR}"/release_bin/[A-Za-z]* "${TGT}"/bin
# Legacy run.sh link
(cd "${TGT}"/bin; ln -s afu_synth run.sh)

# Turn bin/README into the top-level README
sed '1,/^=========/d' "${TGT}"/bin/README > "${TGT}"/README
rm "${TGT}"/bin/README

#
# Export the Quartus PR environment to the target
#
pushd "${WORK_SYN_TOP_PATH}"

# Switch to the PR AFU partition
quartus_sh --prepare -r ${Q_PR_REVISION} ${Q_PROJECT}

# Export a PR build environment as a .qar file. Only sources and scripts required
# for a PR build are exported.
quartus_sh --archive -revision ${Q_PR_REVISION} ${Q_PROJECT} -use_file_set custom -use_file_subset auto -use_file_subset db -use_file_subset qsf -force -output /tmp/${Q_PR_REVISION}.$$.qar

# Import the .qar environment into the build template tree
TGT_BUILD="${TGT}/hw/lib/build"
mkdir -p "${TGT_BUILD}/platform"
# Import into hw/lib/build
(cd "${TGT_BUILD}"; quartus_sh --restore /tmp/${Q_PR_REVISION}.$$.qar)
rm /tmp/${Q_PR_REVISION}.$$.qar*
rm -f "${TGT_BUILD}"/qar_info.json "${TGT_BUILD}"/*.tmp

# Emit the macros defined in the project. These will be used in simulation.
mkdir -p "${TGT_BUILD}"/platform/sim
quartus_sh -t "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/emit_project_macros.tcl --project=${Q_PROJECT} --revision=${Q_PR_REVISION} --output="${TGT_BUILD}"/platform/sim/fim_project_macros.txt
sed -i -e 's/^[A-Za-z]/+define+&/' "${TGT_BUILD}"/platform/sim/fim_project_macros.txt

find_dir_containing() {
  local file="$1"
  local dir="$2"

  test -e "$dir/$file" && echo "$dir" && return 0
  [ '/' = "$dir" ] && return 1

  find_dir_containing "$file" "$(dirname "$dir")"
}

# Copy .tcl and .sdc files in the ipss tree. These aren't specified in the PR build
# but may be loaded during timing analysis.
pushd $(find_dir_containing ipss "$PWD")
rsync -a --include="*.tcl" --include="*.sdc" --include="*/" --exclude="*" --prune-empty-dirs --copy-links ipss/ "${TGT_BUILD}"/ipss/
popd

# Find the path to the actual Quartus root directory
QUARTUS_BUILD_ROOT=$(cd "${TGT_BUILD}"; find syn -name ${Q_PR_REVISION}_sources.tcl -printf '%h')
TGT_QUARTUS_BUILD_ROOT="${TGT_BUILD}/${QUARTUS_BUILD_ROOT}"
rm -f "${TGT_QUARTUS_BUILD_ROOT}"/*.restore.rpt
# db not required and it is large
rm -rf "${TGT_QUARTUS_BUILD_ROOT}"/db "${TGT_QUARTUS_BUILD_ROOT}"/qdb

# Quartus 21.4 started storing megafunction libraries in the archive, with
# no obvious way to skip them.
rm -rf "${TGT_QUARTUS_BUILD_ROOT}"/megafunctions

# Copy scripts and configuration not handled by Quartus
cp -L *.qpf *.qsf "${TGT_QUARTUS_BUILD_ROOT}"/
cp -L *.txt "${TGT_QUARTUS_BUILD_ROOT}"/
mv "${TGT_QUARTUS_BUILD_ROOT}"/fme-ifc-id.txt "${TGT}"/hw/lib/
mkdir -p "${TGT_QUARTUS_BUILD_ROOT}"/output_files
cp -L output_files/${Q_PROJECT}*.*msf  output_files/${Q_PROJECT}*.sof "${TGT_QUARTUS_BUILD_ROOT}"/output_files
cp -Lr ofs_partial_reconfig/ "${TGT_QUARTUS_BUILD_ROOT}"/

mkdir -p "${TGT}"/hw/blue_bits
(cd "${TGT}"/hw/blue_bits; ln -s ../lib/build/"${QUARTUS_BUILD_ROOT}"/output_files/${Q_PROJECT}*.sof .)

# Is there a .bin file for fpgasupdate? If yes, copy it to hw/blue_bits.
if compgen -G "output_files/*_unsigned*.bin" > /dev/null; then
  cp -L output_files/*_unsigned*.bin "${TGT}"/hw/blue_bits/
fi

#
# Update the AFU source to use the PIM and AFUs configured by afu_synth_setup
# by default.
#

# Drop current configuration following the ##### AFU comment tag
AFU_SOURCES_TCL="${TGT_QUARTUS_BUILD_ROOT}"/${Q_PR_REVISION}_sources.tcl
sed -i '/^#* *AFU/q' "${AFU_SOURCES_TCL}"

AFU_MAIN_TCL=$(cd "${TGT_BUILD}"; find . -name afu_main.tcl)

cat >> "${AFU_SOURCES_TCL}" <<EOF

# Import the Platform Interface Manager
set_global_assignment -name SEARCH_PATH "${BUILD_ROOT_REL}/platform"
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE "${BUILD_ROOT_REL}/platform/ofs_plat_if/par/ofs_plat_if_addenda.qsf"

# Map FIM interfaces to the PIM and load AFU-specific sources
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE "${BUILD_ROOT_REL}/${AFU_MAIN_TCL}"

# AFU-specific user clock frequency
set_global_assignment -name SDC_FILE ofs_partial_reconfig/user_clocks.sdc
EOF

# Tcl script that loads AFU sources (loaded by afu_main.tcl)
mkdir -p "${TGT_QUARTUS_BUILD_ROOT}"/afu_with_pim
cat >> "${TGT_QUARTUS_BUILD_ROOT}"/afu_with_pim/afu.tcl <<EOF
# This script will be loaded by afu_main.tcl

# Load AFU-specific sources
set_global_assignment -name SEARCH_PATH "${BUILD_ROOT_REL}/../hw"
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE "${BUILD_ROOT_REL}/../hw/afu.qsf"
EOF

# Configure paths required by afu_synth
cat >> "${TGT}"/bin/build_env_config <<EOF
PIM_INI_NAME="$(basename ${PIM_INI_FILE})"

# Quartus build directory, relative to root of tree configured by afu_synth_setup
QUARTUS_BUILD_DIR="build/${QUARTUS_BUILD_ROOT}"
# Quartus sources root directory from FIM build
export BUILD_ROOT_REL="${BUILD_ROOT_REL}"

# Root directory configured by afu_synth_setup, relative to the Quartus build directory
REL_ROOT_DIR="${BUILD_ROOT_REL}/.."

export Q_PROJECT="${Q_PROJECT}"
export Q_REVISION="${Q_REVISION}"
export Q_PR_REVISION="${Q_PR_REVISION}"
export Q_PR_PARTITION_NAME="${Q_PR_PARTITION_NAME}"
export PR_COMPILE=1
EOF

popd


# Generate file lists of FIM interface sources for use simulation
mkdir -p "${TGT_BUILD}/platform/sim" "${TGT_BUILD}/platform/par"
(cd "${TGT_BUILD}/platform"; "${OFS_PLATFORM_AFU_BBB}"/plat_if_develop/ofs_plat_if/scripts/gen_platform_src_cfg -t . --tgt-rtl .. --gen-prefix fim_afu_if)
# Don't need the Quartus imports -- already handled elsewhere
rm -rf "${TGT_BUILD}/platform/par"

# Special case for IP used by Signal Tap that is not used in simulation. Drop it.
sed -i -n '/\/remote_stp\//!p' "${TGT_BUILD}"/platform/sim/fim_afu_if_addenda.txt

# Move afu_main and simulation modules to fim_afu_if_modules.txt because they depend
# on both the FIM and the PIM.
cat > "${TGT_BUILD}"/platform/sim/fim_afu_if_modules.txt <<EOF
## Modules may depend on both FIM and PIM packages and interfaces.

EOF
grep /afu_main.sv "${TGT_BUILD}"/platform/sim/fim_afu_if_addenda.txt >> "${TGT_BUILD}"/platform/sim/fim_afu_if_modules.txt || true
sed -i -n '/\/afu_main.sv/!p' "${TGT_BUILD}"/platform/sim/fim_afu_if_addenda.txt
grep /port_afu_instances.sv "${TGT_BUILD}"/platform/sim/fim_afu_if_addenda.txt >> "${TGT_BUILD}"/platform/sim/fim_afu_if_modules.txt || true
sed -i -n '/\/port_afu_instances.sv/!p' "${TGT_BUILD}"/platform/sim/fim_afu_if_addenda.txt
grep /sim/ "${TGT_BUILD}"/platform/sim/fim_afu_if_addenda.txt >> "${TGT_BUILD}"/platform/sim/fim_afu_if_modules.txt || true
sed -i -n '/\/sim\//!p' "${TGT_BUILD}"/platform/sim/fim_afu_if_addenda.txt

# Generated IP from the base FIM build should not be loaded during simulation.
# Aside from not being needed for ASE, there are encrypted modules and stubs
# that will not compile. Remove them by loading the paths in fim_base_ip.tcl,
# which lists all IP and was generated at the end of the FIM build, and
# removing the matching paths from the simulator configuration.
set +x
for ip in $(grep 'set_global_assignment.*_FILE ' "${TGT_QUARTUS_BUILD_ROOT}"/fim_base_ip.tcl | sed -e 's/.*_FILE[ ./]*//'); do
  ip_path=${ip%.*}
  echo "Removing IP from simulation: ${ip_path}"
  sed -i "\\^${ip_path}^d" "${TGT_BUILD}"/platform/sim/fim_afu_if_addenda.txt
  sed -i "\\^${ip_path}^d" "${TGT_BUILD}"/platform/sim/fim_afu_if_includes.txt
done
set -x

# Generate the PIM for the target
"${SCRIPT_DIR}"/pim/ofs_pim_setup.sh -t "${TGT}" -n "${PIM_PLATFORM_NAME}" -i "${PIM_INI_FILE}" -p ofs_plat_if

# For simulation, import both the PIM and the FIM sources. The Quartus equivalent handles
# FIM sources as part of the base configuration, so doesn't need this mechanism.
cat >> "${TGT_BUILD}"/platform/ofs_plat_if/sim/platform_if_includes.txt <<EOF
-F ../../sim/fim_project_macros.txt
-F ../../sim/fim_afu_if_includes.txt
-F ofs_plat_if_includes.txt
EOF

cat >> "${TGT_BUILD}"/platform/ofs_plat_if/sim/platform_if_addenda.txt <<EOF
-F ../../sim/fim_project_macros.txt
-F ../../sim/fim_afu_if_addenda.txt
-F ofs_plat_if_addenda.txt
-F ../../sim/fim_afu_if_modules.txt
EOF
