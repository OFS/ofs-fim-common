#!/bin/bash
# Copyright 2023 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Compilation stage of the OFS FIM build flow. The build_fim_setup.sh script
## must already have created the work directory before build_fim_compile.sh is
## run.
##
## This script may either be run from build_top.sh or directly. It consumes
## only a single environment variable: SEED. If set, the project's Quartus
## seed is updated before the compilation.
##

## ********************************************************
##    *** No environment variables are created here! ***
##
##  This is a deliberate design choice for the script so
##  that the scripted flow behaves exactly the same as
##  a build run inside the Quartus GUI.
##
## ********************************************************

set -e

if [ "$2" == "" ]; then
    echo "Usage: build_fim_compile.sh <build target> <work dir>" 1>&2
    exit 1
fi

if [ ! -d "$2" ]; then
    echo "Error: $2 is not a directory!" 1>&2
    echo "" 1>&2
    echo "Usage: build_fim_compile.sh <build target> <work dir>" 1>&2
    exit 1
fi

if [ ! -e "${2}"/quartus_proj_dir ]; then
    # build_fim_setup.sh is supposed to create a link from the top of the
    # work tree to the Quartus build directory.
    echo "Error: No link found at ${2}/quartus_proj_dir!" 1>&2
    exit 1
fi


function chk_exit_code() {
    exit_code=${?}
    if [ "${exit_code}" != "0" ]; then
        echo "Error: ${1} failed. Exit code: ${exit_code}" 1>&2
        exit 1
    fi
    unset exit_code
}


cd "${2}"
# Read the symbolic quartus_proj_dir link and follow the physical dirs
cd -P quartus_proj_dir

############################################
######## Quartus Compilation 

# Now running in the project build directory

# Find the main project name
Q_PROJECT=$(basename -s .qpf *.qpf)
# Find the FIM's base revision. It was written to the build database
# by build_fim_setup.sh.
Q_REVISION=$(grep Q_REVISION build_env_db.txt | sed -e 's/.*=//')

if [ ! -e "${Q_REVISION}".qsf ]; then
    echo "Error: "${Q_REVISION}".qsf not found!"
    exit 1
fi

echo "Compiling ${Q_PROJECT} -c ${Q_REVISION} in ${PWD}"
echo ""

# update_qsf file with SEED value
if [ "${SEED}" != "" ]; then
    sed -i "s/SEED *[0-9]*/SEED ${SEED}/" "${Q_PROJECT}".qsf
    echo "Updated ${Q_PROJECT}.qsf with SEED: ${SEED}"
fi

CMD="quartus_sh --flow compile ${Q_PROJECT} -c ${Q_REVISION}"

# Just a syntax test?
if [ ! -z ${ANALYSIS_AND_ELAB_ONLY} ]; then
    # This will be passed to the compilation flow
    CMD="${CMD} -end synthesis"
fi

# Run the compilation
${CMD}
chk_exit_code "${CMD}"
