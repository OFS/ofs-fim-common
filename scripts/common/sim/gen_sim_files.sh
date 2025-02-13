#!/bin/bash
# Copyright (C) 2022-2023 Intel Corporation
# SPDX-License-Identifier: MIT

# This script generates simulation rtl for all IPs in the Agilex OFS design using the IP list file . The RTL would be generated at the location where a particular IP resides.
# After generating all RTL, the script calls the gen_sim_flist.sh script to automatically generate the simulation flist that will be used in simulation
# Make sure you have the right environment sourced before you run this script.

set -e

usage()
{
   echo "Usage: gen_sim_files.sh [--ofss=<IP config>] <target(s): optional comma separated build_top.sh params> [<device>] [<family>]"
   echo " The script generates HDL for simulation of different FIM targets  "
   echo " Examples - "
   echo " Default :  $0 n6001 AGFB014R24A2E2V  Agilex"
   echo " The device and family are, by default, parsed by the script from the qsf which"
   echo " are assumed to be in a pre-defined location. However, they can also be overridden"
   echo " by passing them as inputs to the script"
   exit -1
}

if [ -z $1 ]; then
   echo "Error: No update target passed in to the script. "
   usage
fi

CORE_COMMAND="$(strings /proc/$PPID/cmdline)"
COMMAND_INVOKED="$(printf %q "$0")$((($#)) && printf ' %q' "$@")" # "

while getopts "\-:h" OP; do
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

      h)
          usage
          ;;

      ?)
      echo -e "Invalid option"
      usage
      ;;
    esac
done
shift $((OPTIND-1))

# Remove the optional trailing colon and variant string.
OFS_TARGET="${1%%:*}"
# Full string to pass options to build_top.sh
OFS_TARGET_FULL=${1}
echo "OFS_TARGET=$OFS_TARGET"
echo "OFS_TARGET_FULL=$OFS_TARGET_FULL"


# Map any --ofss patsh to absolute
unset OFSS_CONFIG_SCRIPT_ARG
if [ ! -z ${OFSS_CONFIG_SCRIPT} ]; then
    IFS=,
    ofss_arr=(${OFSS_CONFIG_SCRIPT})
    unset IFS

    ofss_files_arr=()
    for ofss_rel in "${ofss_arr[@]}"; do
        if [ "${ofss_rel}" == "nodefault" ]; then
            # Keep nodefault
            ofss_files_arr+=(${ofss_rel})
        else
            # Convert paths relative to the original directory to absolute. Also
            # check whether the file exists.
            ofss=$(realpath "${ofss_rel}")
            if [ $? != 0 ]; then
                echo "\"${ofss_rel}\" file not found."
                exit 1
            fi
            if [ ! -f "${ofss}" ]; then
                echo "\"${ofss}\" file not found."
                exit 1
            fi
            ofss_files_arr+=(${ofss})
        fi
    done

    if [ "${ofss_files_arr}" != "" ]; then
        OFSS_CONFIG_SCRIPT_ARG=$(IFS=, ; echo "--ofss=${ofss_files_arr[*]}")
    fi
fi


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
OFS_IP_SEARCH_PATH="$OFS_ROOTDIR/ofs-common/src/common/lib/**/*,$OFS_ROOTDIR/ipss/pmci/**/*,$OFS_ROOTDIR/src/pd_qsys/common/**/*,$OFS_ROOTDIR/src/afu_top/**/*,$"

# Parent directory where IP simulation will be configured
SIM_SETUP_PREFIX="sim/scripts"
SIM_SETUP_DIR="${OFS_ROOTDIR}/${SIM_SETUP_PREFIX}"
echo "SIM_SETUP_DIR=$SIM_SETUP_DIR"
mkdir -p "${SIM_SETUP_DIR}"

# Construct a Quartus project for the target that will be used to
# discover and generate the IP.
PROJECT_NAME=qip_gen_${OFS_TARGET}
PROJECT_PARENT="${SIM_SETUP_DIR}/${PROJECT_NAME}"
PROJECT_DIR="${PROJECT_PARENT}"/quartus_proj_dir
rm -rf "${PROJECT_PARENT}"
rm -rf "${SIM_SETUP_DIR}/qip_gen"

echo "Configuring ${OFS_TARGET} build in ${PROJECT_PARENT}"
# ALLOW_PROJ_IN_OFS_ROOTDIR overrides the normal error triggered
# when configuring a project inside OFS_ROOTDIR. The value of
# ALLOW_PROJ_IN_OFS_ROOTDIR indicates the target OFS_ROOTDIR subtree.
(cd "${OFS_ROOTDIR}"; \
 ALLOW_PROJ_IN_OFS_ROOTDIR=sim ./ofs-common/scripts/common/syn/build_top.sh --stage setup $OFSS_CONFIG_SCRIPT_ARG "${OFS_TARGET_FULL}" "${PROJECT_PARENT}")
# UVM scripts expect qip_gen to point to the tree where qsys-generate is run
(cd "${SIM_SETUP_DIR}"; ln -s "${PROJECT_NAME}" qip_gen)
echo

# Move the log to the project directory so it doesn't pollute the root directory
mv "${OFS_ROOTDIR}/build_fim_${PROJECT_NAME}.log" "${PROJECT_PARENT}/"
Q_PROJECT=$(grep Q_PROJECT "${PROJECT_PARENT}/build_fim_${PROJECT_NAME}.log" | sed -e 's/.*= *//')
Q_REVISION=$(grep Q_REVISION "${PROJECT_PARENT}/build_fim_${PROJECT_NAME}.log" | sed -e 's/.*= *//')

echo "Q_PROJECT=${Q_PROJECT}"
echo "Q_REVISION=${Q_REVISION}"

# figure out the device and family.
# Ideally, it can be figured out from the qsf. It can also be overridden by
# a command line parameter
QSF_FILE="${PROJECT_DIR}/${Q_PROJECT}.qsf"

echo "QSF_FILE=$QSF_FILE"
if [ -v 2 ]; then
    DEVICE=$2
elif [ -f "$QSF_FILE" ]; then
    DEVICE=$(awk '/^set_global_assignment -name DEVICE / {print $4}' "$QSF_FILE")
else
    echo "Error: No target device passed in to the script. "
    usage
fi
echo "DEVICE=$DEVICE"

if [ -v 3 ]; then
    FAMILY=$3
elif [ -f "$QSF_FILE" ]; then
    # Some Quartus tools expect family in all lower case with no spaces
    FAMILY=$(quartus_sh --tcl_eval get_part_info -family $DEVICE | tr -d '"{}[:space:]' | tr '[:upper:]' '[:lower:]')
else
    echo "Error: No target family passed in to the script. "
    usage
fi
echo "FAMILY=$FAMILY"

# Get tile information for the target device in order to support branching to tile specific flows
TILE=$(quartus_sh --tcl_eval get_part_info -sip_tile $DEVICE)
TILE_HIGHSPEED=$(quartus_sh --tcl_eval get_part_info -highspeed_tile $DEVICE)
echo "TILE=$TILE"
echo "TILE_HIGHSPEED=$TILE_HIGHSPEED"

HAS_FTILE=false
if [[ "$TILE" =~ "F-Tile" || "$TILE_HIGHSPEED" =~ "F-Tile" ]]; then
    HAS_FTILE=true
    echo "Configuring F-Tile simulation"
fi
HAS_RTILE=false
if [[ "$TILE" =~ "R-Tile" || "$TILE_HIGHSPEED" =~ "R-Tile" ]]; then
    HAS_RTILE=true
    echo "Configuring R-Tile simulation"
fi

# Find the PIM source repository, needed for scripts. If not already present,
# the repository will already have been fetched by build_top.sh above.
if [ -z "${OFS_PLATFORM_AFU_BBB}" ]; then
    source "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/pim/setup_ofs_platform_afu_bbb.sh
else
    echo "Using provided OFS_PLATFORM_AFU_BBB=${OFS_PLATFORM_AFU_BBB}"
fi

# Clean up any generated files from previous run
rm -f "${SIM_SETUP_DIR}"/generated_*
rm -rf "$SIM_SETUP_DIR"/qip_sim_script

# Save last script invocation command for convenience
echo "$CORE_COMMAND $COMMAND_INVOKED" > "${SIM_SETUP_DIR}"/generated_cmd.f


#
# Run Quartus to load the project and dump a list of IP sources.
#
cd "${OFS_ROOTDIR}"
(cd "${PROJECT_DIR}"
 # Emit a list of IP files
 quartus_ipgenerate -t "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/emit_project_ip.tcl \
                    --project=${Q_PROJECT} --revision=${Q_REVISION} \
                    --output=project_ip_for_sim.tcl 
 
 # Emit configuration header files derived from IP parameters
 quartus_sh -t "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/ip_get_cfg/gen_ofs_ip_cfg_db.tcl \
                    --project=${Q_PROJECT} --revision=${Q_REVISION}

 # Emit a file with all project macros
 quartus_sh -t "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/emit_project_macros.tcl \
                    --project=${Q_PROJECT} --revision=${Q_REVISION} \
                    --output=project_macros_for_sim.f
)

# project_ip_for_sim.tcl now has a Tcl script that refers to each
# IP file present inside Q_PROJECT. All we want is the file names.
# This loop strips everything that isn't a file name and then
# converts the paths to be relative to OFS_ROOTDIR.
(cd "${PROJECT_DIR}"
 for ip in $(grep ^set_global_assignment "${PROJECT_DIR}"/project_ip_for_sim.tcl | sed -e 's/.*_FILE *//'); do
     if [[ ! -f "$ip" ]]; then
         echo "Error: cannot find $ip"
         exit 1
     fi

     realpath --no-symlinks --relative-to="${OFS_ROOTDIR}" "${ip}" >> "${SIM_SETUP_DIR}"/generated_ip_flist.f
 done
)


# Pre-compile a shared version of Quartus simulation libraries. This takes 5-10
# minutes and is independent of other work, so fork a process and do it in the
# background.
QLIBS_DIR="$SIM_SETUP_DIR"/qip_sim_script/quartus_libs
mkdir -p "$QLIBS_DIR"

if command -v vlogan &> /dev/null; then
    mkdir -p "$QLIBS_DIR"/vcsmx
    (cd "$QLIBS_DIR"/vcsmx
     echo "ofs-common/scripts/common/sim/gen_sim_files.sh generated Quartus library script with:" > ../README
     echo "  quartus_sh --simlib_comp -family \"$FAMILY\" -tool vcsmx -language verilog -cmd_file ../vcsmx_cmd_file.sh -gen_only" >> ../README

     quartus_sh --simlib_comp -family "$FAMILY" -tool vcsmx -language verilog -cmd_file ../vcsmx_cmd_file.sh -gen_only &> ../vcsmx.log

     # PCIe PIPE mode enabled?
     is_pcie_pipe_mode=$(grep -c IS_PIPE_MODE "${PROJECT_DIR}"/ofs_ip_cfg_db/ofs_ip_cfg_pcie_ss.vh || true)

     library_defines=""
     if $HAS_FTILE; then
         # F-Tile UVM PCIe/HSSI training depends on some preprocessor macros.
         # Update the command file before running it.
         # See Fast Simulation Macros for the Agilex 7 F-Tile Hard IP
         # https://www.intel.com/content/dam/support/us/en/programmable/kdb/2024/ip/Fast-Simulation-Macros-for-the-Agilex%E2%84%A2%207-F-Tile-Hard-IP.pdf
         library_defines="+define+IP7581SERDES_UX_SIMSPEED +define+TIMESCALE_EN +define+RTLSIM +define+INTC_FUNCTIONAL +define+SSM_SEQUENCE +define+SPEC_FORCE +define+IP7581SERDES_UXS2T1R1PGD_PIPE_SPEC_FORCE +define+IP7581SERDES_UXS2T1R1PGD_PIPE_SIMULATION +define+IP7581SERDES_UXS2T1R1PGD_PIPE_FAST_SIM +define+SRC_SPEC_SPEED_UP +define+__SRC_TEST__ "
         if [ $is_pcie_pipe_mode != 0 ]; then
             library_defines="+define+gdrb_GDR_PCIE_SS_DV ${library_defines}"
             if $HAS_RTILE; then
                 library_defines="+define+RTILE_PIPE_MODE ${library_defines}"
             fi
         fi
     elif [[ "$FAMILY" =~ "agilex5" ]]; then
         # Agilex 5 PCIe training macros
         library_defines="+define+IP7581SERDES_UX_SIMSPEED "
         if [ $is_pcie_pipe_mode != 0 ]; then
             library_defines="+define+SM_PIPE_MODE ${library_defines}"
         fi
     else
         if [ $is_pcie_pipe_mode != 0 ]; then
             echo "ERROR: gen_sim_files.sh detects PIPE mode enabled but the tile-specific macro is not configured."
             echo "ERROR: gen_sim_files.sh detects PIPE mode enabled but the tile-specific macro is not configured." >> ../README
             exit 1
         fi
     fi

     if [ ! -z "$library_defines" ]; then
         echo "" >> ../README
         echo "Added tile-specific macros:" >> ../README
         echo "  ${library_defines}" >> ../README
     fi

     # Generate a configuration file that can be included by Verilog simulator compilation, for both
     # Quartus libraries and downstream simulator builds.
     echo "# Macros to apply to Verilog compilation" > ../simlib_defs.f
     echo "${library_defines}" >> ../simlib_defs.f

     # Apply the macros to the Quartus libraries
     sed -i -e "sX^vlogan Xvlogan -F ../simlib_defs.f X" ../vcsmx_cmd_file.sh

     # Parse the sources
     chmod a+x ../vcsmx_cmd_file.sh
     ../vcsmx_cmd_file.sh &>> ../vcsmx.log

     # Rename the hidden generated setup file to a visible one that other scripts expect
     if [ -f "$QLIBS_DIR"/vcsmx/.synopsys_vss.setup ]; then
         mv "$QLIBS_DIR"/vcsmx/.synopsys_vss.setup "$QLIBS_DIR"/vcsmx/synopsys_sim.setup
     fi
    ) &
fi


echo "**** Generating HDL for $OFS_TARGET ****"

unset batch_ip_list
while read ip
do
    # Shorten the IP path because all of them will be on the command line to qsys-generate
    ip=$(realpath --relative-to "${PROJECT_PARENT}" "${ip}")

    if [ -z "$batch_ip_list" ]; then
        batch_ip_list=r/"$ip"
    else
        batch_ip_list="$batch_ip_list --batch=r/$ip"
    fi
done < "${SIM_SETUP_DIR}"/generated_ip_flist.f

qsys_gen_extra_args=""
if [ ! -z "${__NB_JOBID}" -a ! -z "${ARC_JOB_STORAGE}" ]; then
    # Reduce parallelism when running in the Intel batch farm
    qsys_gen_extra_args="--parallel=off"
fi

if $HAS_FTILE; then
    # Generate synthesis files for quartus elaboration during TLG
    qsys_gen_extra_args="$qsys_gen_extra_args --synthesis=VERILOG"
fi

(cd "${PROJECT_DIR}"
 # batch_ip_list list expects "r" to link from the project directory to the root directory
 rm -rf r; ln -s "${PROJECT_PARENT}" r
 qsys-generate ${qsys_gen_extra_args} --simulation=VERILOG --simulator=VCS,VCSMX,MODELSIM --search-path="$OFS_IP_SEARCH_PATH" \
    $batch_ip_list \
    --quartus-project=${Q_PROJECT} --rev=${Q_REVISION}
)
if [ $? -ne 0 ]; then
    echo "HDL generation failed. Check the errors for details."
    exit -1
fi

echo "**** Done generating HDL for $OFS_TARGET ****"

# Quartus Tile logic generation (F-Tile specific flow)
if $HAS_FTILE; then
    (cd "${PROJECT_DIR}"
     echo "**** Generating support logic files ****"
     quartus_tlg  ${Q_PROJECT} -c ${Q_REVISION}
    )
    if [ $? -ne 0 ]; then
        echo "F-Tile support logic generation failed. Check the errors for details."
        exit -1
    fi
    echo '## Macros needed to simulate F-Tile connected components' >> "${SIM_SETUP_DIR}"/generated_ftile_macros.f
    echo '+define+FTILE_SIM' >> "${SIM_SETUP_DIR}"/generated_ftile_macros.f
    echo '' >> "${SIM_SETUP_DIR}"/generated_ftile_macros.f
    echo "**** Done generating F-Tile support logic for $OFS_TARGET ****"
fi


# Create the RTL source list. This should be done after the TLG step loads tile specific source into the quartus project.
(cd "${PROJECT_DIR}"
 # Emit a list of RTL sources. qsys-generate --synthesis will pollute the project filelist database with files that are
 # unfriendly to simulators, so exclude them.
 quartus_sh -t "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/emit_project_sources.tcl \
                    --project=${Q_PROJECT} --revision=${Q_REVISION} \
                    --output=project_sources_rtl_for_sim.f \
                    --exclude-synth-files=true
)

(cd "${PROJECT_DIR}"

 # Import some macros from the Quartus project, turing the list of macros into
 # +define+ form for the simulator. Comment out any macros beginning with
 # INCLUDE_ so that individual features can be controlled by the simulator
 # configuration.
 echo '## Project macros with INCLUDE_* commented out so simulator configuration' > "${SIM_SETUP_DIR}"/generated_rtl_flist_macros.f
 echo '## choses OFS features. Updated by gen_sim_files.sh.' >> "${SIM_SETUP_DIR}"/generated_rtl_flist_macros.f
 echo '' >> "${SIM_SETUP_DIR}"/generated_rtl_flist_macros.f
 sed -e 's/^\([A-Za-z]\)/+define+\1/' -e 's/\(+define+INCLUDE_\)/# \1/' project_macros_for_sim.f >> "${SIM_SETUP_DIR}"/generated_rtl_flist_macros.f

 # Uncomment any macro defining a tile. We assume tile-dependent features
 # are required.
 sed -i '/TILE$/s/^# *//g' "${SIM_SETUP_DIR}"/generated_rtl_flist_macros.f

 # Uncomment the memory technology macro. It is still controlled by INCLUDE_LOCAL_MEM
 # so enabling the technology macro allows the project to autoconfigure the testbench for tests that enable local mem.
 sed -i '/DDR[0-9]\+$/s/^# *//g' "${SIM_SETUP_DIR}"/generated_rtl_flist_macros.f
 sed -i '/HBM$/s/^# *//g' "${SIM_SETUP_DIR}"/generated_rtl_flist_macros.f

 # Include paths. Strip +incdir+, change the path, then put +incdir+ back.
 grep '^+incdir+' project_sources_rtl_for_sim.f > project_sources_rtl_incdirs.f
 for inc_path in $(cat project_sources_rtl_incdirs.f | colrm 1 8); do
     echo -n '+incdir+' >> "${SIM_SETUP_DIR}"/generated_rtl_flist_incdirs.f
     realpath --no-symlinks --relative-to="${SIM_SETUP_DIR}" "${inc_path}" >> "${SIM_SETUP_DIR}"/generated_rtl_flist_incdirs.f
 done

 # Sort SystemVerilog packages in dependence order. Package file names must
 # be either *_pkg.sv, *_def.sv or *_defs.sv.
 echo ""
 echo "Sorting SystemVerilog packages in dependence order..."
 grep '_pkg\.sv$\|_def\.sv$\|_defs\.sv$' project_sources_rtl_for_sim.f | \
     "$OFS_PLATFORM_AFU_BBB"/plat_if_develop/ofs_plat_if/scripts/sort_sv_pkgs --incdir project_sources_rtl_incdirs.f \
                                                                              --target project_sources_rtl_pkgs.f

 for pkg_file in $(cat project_sources_rtl_pkgs.f); do
     if [[ ! -f "$pkg_file" ]]; then
         echo "Error: cannot find $pkg_file"
         exit 1
     fi
     realpath --relative-to="${SIM_SETUP_DIR}" "${pkg_file}" >> "${SIM_SETUP_DIR}"/generated_rtl_flist_pkgs.f

 done

 # Normal Verilog and SystemVerilog sources
 for rtl_file in $(grep '\.v\|\.sv' project_sources_rtl_for_sim.f | grep -v '_pkg\.sv$\|_def\.sv$\|_defs\.sv$'); do
     if [[ ! -f "$rtl_file" ]]; then
         echo "Error: cannot find $rtl_file"
         exit 1
     fi
     realpath --relative-to="${SIM_SETUP_DIR}" "${rtl_file}" >> "${SIM_SETUP_DIR}"/generated_rtl_flist_verilog.f
 done

 # VHDL sources
 touch "${SIM_SETUP_DIR}"/generated_rtl_flist_vhdl.f
 for rtl_file in $(grep '\.vhd' project_sources_rtl_for_sim.f); do
     if [[ ! -f "$rtl_file" ]]; then
         echo "Error: cannot find $rtl_file"
         exit 1
     fi
     realpath --relative-to="${SIM_SETUP_DIR}" "${rtl_file}" >> "${SIM_SETUP_DIR}"/generated_rtl_flist_vhdl.f
 done
)

# Wrapper file to import SystemVerilog sources
cat > "${SIM_SETUP_DIR}"/generated_rtl_flist.f <<EOF
# Load SystemVerilog sources and configuration

-F generated_rtl_flist_macros.f
-F generated_rtl_flist_incdirs.f
-F generated_rtl_flist_pkgs.f
-F generated_rtl_flist_verilog.f
EOF

echo "**** Generating simulation setup for $OFS_TARGET ****"

unset spd_list
while read ip
do
    ip_dir=$(dirname -- $ip)
    ip_file=$(basename -- $ip)
    ip_name=$(echo $ip_file | sed -e "s/\..*$//g")

    spd="${ip_dir}/${ip_name}/${ip_name}.spd"
    spd_tmp="${ip_dir}/${ip_name}/${ip_name}_tmp.spd"
    cp "${OFS_ROOTDIR}/$spd" "${OFS_ROOTDIR}/$spd_tmp"
    sed '/\<device name=/d' -i "${OFS_ROOTDIR}/$spd_tmp"

    if [ -z "$spd_list" ]; then
        spd_list="${OFS_ROOTDIR}/$spd_tmp"
    else
        spd_list="${spd_list}, ${OFS_ROOTDIR}/$spd_tmp"
    fi
done < "$SIM_SETUP_DIR"/generated_ip_flist.f

ip-make-simscript --spd="${spd_list}" --use-relative-paths --output-directory="$SIM_SETUP_DIR"/qip_sim_script --device-family="$FAMILY"

make_simscript_status=$?
if [ $make_simscript_status -ne 0 ]; then
    echo "Simulation setup generation failed. Check the errors for details."
    exit -1
fi

# Wait for the background job that is building Quartus simulation libraries
echo "Waiting for quartus_sh --simplib_comp to finish..."
wait
if [ $? -ne 0 ]; then
    echo "quartus_sh --simplib_comp error while generating $QLIBS_DIR"
    exit -1
fi

echo "**** Done generating simulation setup for $OFS_TARGET ****"

echo "**** Generating filelist for $OFS_TARGET ****"

python $SCRIPT_DIR/gen_sim_filelist.py --qsys_list="$SIM_SETUP_DIR/generated_ip_flist.f" --output_file="$SIM_SETUP_DIR/ip_flist.sh"
python ${OFS_ROOTDIR}/ofs-common/sim/bfm/ofs_axis_bfm/gen_pfvf_def_pkg.py


if [ $? -ne 0 ]; then
    echo "Simulation filelist generation failed. Check the errors for details."
    exit -1
fi

# Create MSIM list
cp $SIM_SETUP_DIR/ip_flist.sh $SIM_SETUP_DIR/msim_ip_flist.sh
sed -i -e 's/synopsys/mentor/' -e 'sX/ip_flist.fX/msim_ip_flist.fX' $SIM_SETUP_DIR/msim_ip_flist.sh
cp $SIM_SETUP_DIR/ip_flist.f $SIM_SETUP_DIR/msim_ip_flist.f
sed -i 's/synopsys/mentor/' $SIM_SETUP_DIR/msim_ip_flist.f

rm -rf design_files.txt
rm -rf memory_files.txt
rm -rf *.hex
rm -rf *.mif

echo "**** Done generating SIM filelist for $OFS_TARGET ****"
