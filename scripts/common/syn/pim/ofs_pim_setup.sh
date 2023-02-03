#!/bin/bash

##
## Add the Platform Interface Manager (PIM) to the build environment.
##

usage() {
  echo "Usage: $0 -t <tgt dir> -n <platform name> -i <platform .ini file>" 1>&2
  echo "                [-d <disable interfaces>]" 1>&2
  echo "" 1>&2
  echo "  The -d option is rarely used. It can be used to disable one or more" 1>&2
  echo "  interface classes defined in the .ini file. The option may be useful" 1>&2
  echo "  during development, when an interface class isn't fully implemented." 1>&2
  echo "" 1>&2
  exit 1
}

TGT=""
PLATFORM_NAME=""
PLATFORM_INI=""
PIM_DISABLE_IF=""
PLATFORM_IF_PREFIX=""

while getopts "t:n:i:d:p:" OP; do
  case "${OP}" in
    t)
      TGT="${OPTARG}"
      ;;
    n)
      PLATFORM_NAME="${OPTARG}"
      ;;
    i)
      PLATFORM_INI="${OPTARG}"
      ;;
    d)
      PIM_DISABLE_IF="${OPTARG}"
      ;;
    p)
      PLATFORM_IF_PREFIX="${OPTARG}"
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
if [ "${PLATFORM_NAME}" == "" ]; then
  echo "Platform name not specified!" 1>&2
  echo "" 1>&2
  usage
fi
if [ "${PLATFORM_INI}" == "" ]; then
  echo "Platform .ini filename not specified!" 1>&2
  echo "" 1>&2
  usage
fi

if [ ! -f "${PLATFORM_INI}" ]; then
  echo "Platform .ini filename not found: ${PLATFORM_INI}" 1>&2
fi

# Disable some interfaces? Simulation may do this, eliminating drivers for some
# devices, in order to speed up simulation.
if [ "${PIM_DISABLE_IF}" != "" ]; then
  PIM_DISABLE_IF="--disable ${PIM_DISABLE_IF}"
fi

# Use names other than the default platform_if_addenda.qsf, etc. for the files
# that import the PIM?
if [ "${PLATFORM_IF_PREFIX}" != "" ]; then
  PLATFORM_IF_PREFIX="--gen-prefix ${PLATFORM_IF_PREFIX}"
fi

# Require the PIM source
if [ "${OFS_PLATFORM_AFU_BBB}" == "" ]; then
  source "${OFS_ROOTDIR}"/ofs-common/syn/common/scripts/pim/setup_ofs_platform_afu_bbb.sh
fi

if [ ! -x "${OFS_PLATFORM_AFU_BBB}"/plat_if_develop/ofs_plat_if/scripts/gen_ofs_plat_if ]; then
  echo ${OFS_PLATFORM_AFU_BBB}/plat_if_develop/ofs_plat_if/scripts/gen_ofs_plat_if not found!
  exit 1
fi

# Generate a platform-specific PIM instance
rm -rf "${TGT}"/hw/lib/platform/platform_db
mkdir -p "${TGT}"/hw/lib/platform/platform_db

# Add interface types. The original base set of interfaces is defined in the OPAE SDK.
# The PIM may add more. The afu_platform_config tool will search in the afu_top_ifc_db
# directory.
if [ -d "${OFS_PLATFORM_AFU_BBB}"/plat_if_develop/ofs_plat_if/src/config/afu_top_ifc_db ]; then
  cp -Lr "${OFS_PLATFORM_AFU_BBB}"/plat_if_develop/ofs_plat_if/src/config/afu_top_ifc_db "${TGT}"/hw/lib/platform/
fi

rm -rf "${TGT}"/hw/lib/build/platform/ofs_plat_if
mkdir -p "${TGT}"/hw/lib/build/platform
echo ${PLATFORM_NAME} > "${TGT}"/hw/lib/fme-platform-class.txt
# Generate the JSON database required by afu_platform_config
${OFS_PLATFORM_AFU_BBB}/plat_if_develop/ofs_plat_if/scripts/gen_ofs_plat_json ${PIM_DISABLE_IF} -c "${PLATFORM_INI}" "${TGT}"/hw/lib/platform/platform_db/${PLATFORM_NAME}.json
# Generate the PIM sources
set -x
${OFS_PLATFORM_AFU_BBB}/plat_if_develop/ofs_plat_if/scripts/gen_ofs_plat_if ${PIM_DISABLE_IF} -c "${PLATFORM_INI}" -v -t "${TGT}"/hw/lib/build/platform/ofs_plat_if ${PLATFORM_IF_PREFIX}
set +x

# Preserve imported FIM sources in case update_pim is used later.
for d in $(grep ^import= "${PLATFORM_INI}"); do
  echo "d is $d"
  IMPORT_SRC_PATH=${d/import=/}
  # Relative path to the .ini file? Find the source directory.
  if [ "${IMPORT_SRC_PATH}" != "/*" ]; then
    IMPORT_SRC_PATH="$(dirname "${PLATFORM_INI}")"/"${IMPORT_SRC_PATH}"
  fi

  mkdir -p "${TGT}"/hw/lib/platform/platform_db/import/
  echo "TGT = $TGT"
  echo "IMPORT_SRC_PATH = $IMPORT_SRC_PATH"
  cp -Lr "${IMPORT_SRC_PATH}" "${TGT}"/hw/lib/platform/platform_db/import/
  find "${TGT}"/hw/lib/platform/platform_db/import/ -name '*~' -exec rm \{} \;
done

# Copy the platform .ini file but change any import paths to the preserved platform_db/import tree
cat "${PLATFORM_INI}" | sed -e 'sx/[[:space:]]*$xx' -e 'sx^import=.*/ximport=import/x' > "${TGT}"/hw/lib/platform/platform_db/"$(basename "${PLATFORM_INI}")"

cat > "${TGT}"/README <<EOF
This tree was created by ofs_pim_setup.sh. The RTL below is the Platform Interface
Manager (PIM), configured specifically for the target FIM using:

Configuration file: ${PLATFORM_INI}
Platform name:      ${PLATFORM_NAME}
PIM sources:        ${OFS_PLATFORM_AFU_BBB}
EOF
