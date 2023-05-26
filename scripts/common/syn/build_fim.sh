#!/bin/bash
# Copyright 2023 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Run the full build_fim flow (the "all" stage to build_top.sh)
##
## Two arguments are expected and they are passed to the scripts
## that implement each stage: <build target> <work dir>.
##

SCRIPTNAME="$(basename -- "$0")"
SCRIPT_DIR="$(cd "$(dirname -- "$0")" 2>/dev/null && pwd -P)"

set -e

##
## Scripts are NOT sourced in order to avoid polluting the compilation
## stage's environment variables. Compilation with the Quartus GUI and
## build_fim_compile.sh are intended to be identical and loading all
## the environment variables from build_fim_setup.sh would make testing
## this equivalence difficult.
##

"${SCRIPT_DIR}"/build_fim_setup.sh "$@"
"${SCRIPT_DIR}"/build_fim_compile.sh "$@"

# Finish as long as the mode isn't synthesis-only
if [ -z ${ANALYSIS_AND_ELAB_ONLY} ]; then
    "${SCRIPT_DIR}"/build_fim_finish.sh "$@"
fi
