# Copyright (C) 2020 Intel Corporation.
# SPDX-License-Identifier: MIT
#

if test -n "$BASH" ; then SCRIPT_NAME=$BASH_SOURCE
elif test -n "$TMOUT"; then SCRIPT_NAME=${.sh.file}
elif test -n "$ZSH_NAME" ; then SCRIPT_NAME=${(%):-%x}
elif test ${0##*/} = dash; then x=$(lsof -p $$ -Fn0 | tail -1); SCRIPT_NAME=${x#n}
else SCRIPT_NAME=$0
fi

# Defaults (1/2)
VCSMX=0
MSIM=0
SKIP_IP_CMP=0
TEST=0
ELAB_OPTIONS=""
SIM_OPTIONS=""
SKIP_SIM=0;
TOP_LEVEL_NAME="top_tb"
USER_DEFINED_SIM_OPTIONS=""
USER_DEFINED_ELAB_OPTIONS=""

# ----------------------------------------
# overwrite variables - DO NOT MODIFY!
# This block evaluates each command line argument, typically used for 
# overwriting variables. An example usage:
#   sh run_sim.sh SKIP_IP_CMP=1
echo $@
for expression in "$@"; do
  eval $expression
  if [ $? -ne 0 ]; then
    echo "Error: This command line argument, \"$expression\", is/has an invalid expression." >&2
    exit $?
  fi
done

# Directory variable declarations
UNIT_TEST_DIR=$OFS_ROOTDIR/sim/unit_test
COMMON_SCRIPT_DIR=$OFS_ROOTDIR/sim/unit_test/scripts

# Check that valid test was specified

if [ -z "$OFS_ROOTDIR" ] ; then
   echo "OFS_ROOTDIR not set, follow "Environment Set Up" instructions at https://github.com/intel-innersource/applications.fpga.ofs.reference-fims/wiki/OFS-Wiki"
   exit 1
fi

if [ -z "$TEST" ] || [ ! -d "$UNIT_TEST_DIR/$TEST" ]; then
    echo "Error: ensure the TEST variable is set to the relative path to the test you would like to run from the unit_test directory."
    exit 1
fi

# Test directory
# TEST_SRC_DIR="$(cd $UNIT_TEST_DIR/$TEST/"$(dirname -- "$SCRIPT_NAME")" 2>/dev/null && pwd -P)"
TEST_SRC_DIR="$UNIT_TEST_DIR/$TEST"
echo "run_sim.sh: TEST_SRC_DIR=$TEST_SRC_DIR"

echo "UNIT_TEST_DIR=$UNIT_TEST_DIR"
echo "COMMON_SCRIPT_DIR=$COMMON_SCRIPT_DIR"
echo "SCRIPT_NAME=$SCRIPT_NAME"

# Defaults (2/2)
TEST_DIR=$TEST_SRC_DIR
TEST_BASE_DIR=$TEST_SRC_DIR
THE_PLATFORM=$OFS_ROOTDIR

# ----------------------------------------
# initialize simulation properties - DO NOT MODIFY!
if [[ `vcs -platform` != *"amd64"* ]]; then
  :
else
  :
fi

# Source common sim setup script
echo "run_sim.sh: running: $OFS_ROOTDIR/sim/unit_test/scripts/sim_setup_common.sh TEST_DIR=$TEST_DIR VCSMX=$VCSMX MSIM=$MSIM"
. $OFS_ROOTDIR/sim/unit_test/scripts/sim_setup_common.sh TEST_DIR="$TEST_DIR" VCSMX=$VCSMX MSIM=$MSIM 


# Directory and parameter setup
if [ $VCSMX -eq 1 ]; then
   echo "Running VCSMX simulation in $TEST_DIR/sim_vcsmx"
   echo "run_sim.sh: running: cd ${TEST_DIR}/sim_vcsmx"
   # echo "run_sim.sh: running: sh ${TEST_SRC_DIR}/vcs_vcsmx_setup.sh VCSMX=$VCSMX"
   cd ${TEST_DIR}/sim_vcsmx || { echo "run_sim.sh: cd ${TEST_DIR}/sim_vcsmx failed" ; exit 1 ; }
   SIM_DIR="${TEST_DIR}/sim_vcsmx"
   . ${SIM_DIR}/vcs_filelist.sh
   USER_DEFINED_SIM_OPTIONS='+vcs -l ./transcript'
   USER_DEFINED_ELAB_OPTIONS='-debug_acc+pp+dmptf -debug_region+cell+encrypt'
   VLOGAN_PARAMS=""
elif [ $MSIM -eq 1 ]; then
   echo "Running Questasim simulation in $TEST_DIR/sim_msim"
   cd ${TEST_DIR}/sim_msim || { echo "run_sim.sh: cd ${TEST_DIR}/sim_msim failed" ; exit 1 ; } 
   USER_DEFINED_ELAB_OPTIONS=""
   USER_DEFINED_SIM_OPTIONS="-finish exit"
   SIM_DIR="${TEST_DIR}/sim_msim"
   . ${SIM_DIR}/msim_filelist.sh
   USER_DEFINED_SIM_OPTIONS='-l ./transcript'
   USER_DEFINED_ELAB_OPTIONS=""
   VLOG_PARAMS="+libext+.v+.sv" 

else # VCS
   echo "Running VCS simulation in $TEST_DIR/sim_vcs"
   cd ${TEST_DIR}/sim_vcs || { echo "run_sim.sh: cd ${TEST_DIR}/sim_vcs failed" ; exit 1 ; } 
   USER_DEFINED_ELAB_OPTIONS=""
   USER_DEFINED_SIM_OPTIONS='+vcs+finish+100'
   SIM_DIR="${TEST_DIR}/sim_vcs"
   . ${SIM_DIR}/vcs_filelist.sh
   USER_DEFINED_SIM_OPTIONS='+vcs -l ./transcript'
   USER_DEFINED_ELAB_OPTIONS='-debug_acc+pp+dmptf -debug_region+cell+encrypt'

fi

# Filelist setups

if [ -e "$TEST_SRC_DIR/msim_filelist.sh" ] && [ $MSIM -eq 1 ]; then 
   cp ${TEST_DIR}/msim_filelist.sh $SIM_DIR 
   . ${TEST_DIR}/msim_filelist.sh
elif [ -e "$TEST_SRC_DIR/vcs_filelist.sh" ] ; then
   cp ${TEST_DIR}/vcs_filelist.sh $SIM_DIR 
   . ${TEST_DIR}/vcs_filelist.sh
else
   . $COMMON_SCRIPT_DIR/vcs_filelist.sh
fi

TB_SRC=""

if [ -e "$TEST_SRC_DIR/tb_src.f" ] ; then
   TB_SRC=$(cat -e $TEST_SRC_DIR/tb_src.f)
   TB_SRC="$(eval "echo \"$TB_SRC\"")"
   BASE_AFU_SRC=""
else 
   # Load packages first. Choose alphabetical order so all runs are the same.
   PKG_FILES=($(find "$TEST_BASE_DIR" -type f -name '*.sv' | grep    -E '_(pkg|defs)\.sv$' | sort))
   SV_FILES=($(find  "$TEST_BASE_DIR" -type f -name '*.sv' | grep -v -E '_(pkg|defs)\.sv$' | sort))
   for SV_FILE in "${PKG_FILES[@]}" "${SV_FILES[@]}" ; do
      if [[ "$SV_FILE" != *"tester_tests.sv"* ]] && [[ "$SV_FILE" != *"top_tb.sv"* ]] && [[ "$SV_FILE" != *"declarations.sv"* ]] ; then
         TB_SRC="$TB_SRC $SV_FILE"
         echo "SV_FILE=$SV_FILE"
      fi
   done
   echo "TB_SRC=$TB_SRC"
   if [[ $TEST == *pmci* ]] ; then
      TB_SRC="$TB_SRC $TEST_SRC_DIR/../pmci_coverage_interface/pmci_interface.sv"
      cp -f $OFS_ROOTDIR/ipss/pmci/pmci_ss_nios_fw.hex $SIM_DIR
   fi

#  Now putting the BFM sources before the testbench so that the testbench
#  can utilize the classes defined in the BFM.
   TB_SRC="$BFM_SRC $TB_SRC "
fi

if [ -e "$TEST_SRC_DIR/cm_hier.file" ] ; then
   cp -rf $TEST_SRC_DIR/cm_hier.file $SIM_DIR
fi

TEST_NAME="`echo $TEST_SRC_DIR|grep -o '[^/]\+$'`"

MSIM_OPTS=(-c opt -suppress 7033,12023,3053,2244,2388 -do "run -all ; quit -f")
VCS_SIMV_PARAMS="$SIM_OPTIONS $USER_DEFINED_SIM_OPTIONS -l transcript -assert nopostproc"
NTB_OPTS=""
VLOG_SUPPRESS="8386,7033,7061,12003,2244,2388"
VOPT_SUPPRESS=""
SV_OPTS=""
VCS_CM_PARAMS=""
CM_OPTIONS=""
VCS_ERROR_COUNT="+error+1"

if [ -e "$TEST_SRC_DIR/set_params.sh" ] ; then
   source $TEST_SRC_DIR/set_params.sh 
fi

if [ ! -z "$INCLUDE_HSSI_LIB" ]; then
    if [ $MSIM -eq 1 ]; then
        MSIM_FILELIST="$MSIM_FILELIST $HSSI_LIB_FILELIST"
    else
        VCS_FILELIST="$VCS_FILELIST $HSSI_LIB_FILELIST"
    fi
fi

if [ ! -z "$AFU_WITH_PIM" ]; then
  # Construct the simulation build environment for the target AFU. A common
  # script can be used for UVM and unit tests on all targets. The script
  # will generate a simulator include file afu_with_pim/afu_sim_files.list.
  $OFS_ROOTDIR/ofs-common/scripts/common/sim/ofs_pim_sim_setup.sh \
      -t ${PWD}/afu_with_pim \
      -r $OFS_ROOTDIR/sim/scripts/qip_gen/quartus_proj_dir/afu_with_pim/pim_template \
      "${AFU_WITH_PIM}"

  # Load AFU and PIM sources into simulation
  BASE_AFU_SRC="-F afu_with_pim/afu_sim_files.list"
fi

# Info dump for debugging
echo "run_sim.sh: TEST_DIR=$TEST_DIR"
echo
echo echo "MSIM=$MSIM"
echo "VCSMX=$VCSMX"
echo "COMMON_SCRIPT_DIR=$COMMON_SCRIPT_DIR"
echo "TEST_DIR=$TEST_DIR"
echo "TEST_SRC_DIR=$TEST_SRC_DIR"
echo "TEST_BASE_DIR=$TEST_BASE_DIR"
echo "VCS_FILELIST=$VCS_FILELIST"
echo "BASE_AFU_SRC=$BASE_AFU_SRC"
echo "INC_DIR=$INC_DIR"
echo "MSIM_FILELIST=$MSIM_FILELIST"
echo "TOP_LEVEL_NAME=$TOP_LEVEL_NAME"
echo "OFS_ROOTDIR='$OFS_ROOTDIR'"
echo "BFM_SRC=$BFM_SRC"
echo "TB_SRC=$TB_SRC"
echo "DEFINES=$DEFINES"
echo "NTB_OPTS=$NTB_OPTS"
echo "USER_DEFINED_ELAB_OPTIONS=$USER_DEFINED_ELAB_OPTIONS"
echo "ELAB_OPTIONS=$ELAB_OPTIONS"
echo "USER_DEFINED_SIM_OPTIONS=$USER_DEFINED_SIM_OPTIONS"
echo "VLOG_OPTIONS=$VLOG_OPTIONS"
echo "MSIM_OPTS=${MSIM_OPTS[@]}"
echo "VCS_SIMV_PARAMS=$VCS_SIMV_PARAMS"
echo "VLOG_PARAMS=$VLOG_PARAMS"
echo "V_OPTS=$V_OPTS"
echo "VOPT_SUPPRESS=${VOPT_SUPPRESS[@]}"
echo "VCS_CM_PARAMS=${VCS_CM_PARAMS[@]}"
echo 
# exit 0

#Get start time for each simulation
start_time="$(date -u +%s)"

if [ $VCSMX -eq 1 ] ; then
    vlogan -lca -timescale=1ps/1ps $VLOGAN_PARAMS -full64 -sverilog +vcs+lic+wait +systemverilogext+.sv+.v -error=noMPD -ntb_opts dtm \
        +lint=TFIPC-L \
        -ignore initializer_driver_checks \
        $DEFINES \
        $ELAB_OPTIONS $USER_DEFINED_ELAB_OPTIONS \
        $USER_DEFINED_VLOG_OPTIONS \
        +incdir+./ \
        +incdir+$TEST_SRC_DIR/ \
        $INC_DIR \
        $VCS_FILELIST \
        $BASE_AFU_SRC \
        $TB_SRC +error+1 -l vlog.log 

    vcs -full64 -ntb_opts -licqueue +vcs+lic+wait \
        $QUARTUS_ROOTDIR/eda/sim_lib/quartus_dpi.c \
        $QUARTUS_ROOTDIR/eda/sim_lib/simsf_dpi.cpp \
        +lint=TFIPC-L \
        -ignore initializer_driver_checks \
        $ELAB_OPTIONS $USER_DEFINED_ELAB_OPTIONS -l vcs.log $TOP_LEVEL_NAME 

    # ----------------------------------------
    # simulate
    # parse transcript to remove redundant comment block (fb:435978)
    if [ $SKIP_SIM -eq 0 ]; then
        ./simv $SIM_OPTIONS $USER_DEFINED_SIM_OPTIONS -l transcript
    fi

elif [ $MSIM -eq 1 ] ; then

    vlib work
    vlog -mfcu -timescale=1ps/1ps $VLOG_PARAMS -lint -sv $SV_OPTS\
        $DEFINES \
        $ELAB_OPTIONS $USER_DEFINED_ELAB_OPTIONS \
        +incdir+./ \
        +incdir+$TEST_SRC_DIR/ \
        $MSIM_FILELIST \
        $BASE_AFU_SRC \
        $TB_SRC -work work -l msim_vlog.log -suppress $VLOG_SUPPRESS
 
    # ----------------------------------------
    # simulate
    # parse transcript to remove redundant comment block (fb:435978)
    if [ $SKIP_SIM -eq 0 ]; then
      vopt $TOP_LEVEL_NAME -o opt -access=rw+/. "${VOPT_SUPPRESS[@]}"
      vsim "${MSIM_OPTS[@]}"
    fi
else # VCS

    vcs -lca $CM_OPTIONS \
        -timescale=1ps/1ps -full64 -sverilog +vcs+lic+wait +systemverilogext+.sv+.v -ntb_opts dtm \
        $QUARTUS_ROOTDIR/eda/sim_lib/quartus_dpi.c \
        $QUARTUS_ROOTDIR/eda/sim_lib/simsf_dpi.cpp \
        $NTB_OPTS \
        +lint=TFIPC-L \
        -ignore initializer_driver_checks \
        $DEFINES \
        $ELAB_OPTIONS $USER_DEFINED_ELAB_OPTIONS \
        +incdir+./ \
        +incdir+$TEST_SRC_DIR/ \
        $VCS_FILELIST \
        $BASE_AFU_SRC \
        $TB_SRC -top $TOP_LEVEL_NAME $VCS_ERROR_COUNT -l vcs.log "${VCS_CM_PARAMS[@]}"

    # ----------------------------------------
    # simulate
    # parse transcript to remove redundant comment block (fb:435978)

   echo "VCS_SIMV_PARAMS=$VCS_SIMV_PARAMS"
    if [ $SKIP_SIM -eq 0 ]; then
        ./simv $VCS_SIMV_PARAMS
    fi
fi
   
end_time="$(date -u +%s)"
elapsed="$((($end_time-$start_time)/60))"
echo "Total of $elapsed minutes elapsed for $TEST"

echo "run_sim.sh: USER_DEFINED_SIM_OPTIONS $USER_DEFINED_SIM_OPTIONS"

echo "run_sim.sh: run_sim.sh DONE!"
