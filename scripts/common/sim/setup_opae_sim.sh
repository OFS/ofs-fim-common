#!/bin/bash
# Copyright (C) 2021-2022 Intel Corporation
# SPDX-License-Identifier: MIT

#################################################################################
### The main purpose of this script is to clone opae-sim and build only the parts
### which are required during simulation setup.

# enforce sourcing this script
# Note that this section needs to be the first thing this script does
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    echo "This script sets up env variables used by the build scripts"
    echo "Script must be sourced"
    echo "Usage: source ${BASH_SOURCE[0]}"
    exit 1
fi

# Check for $OFS_ROOTDIR and set to cloned repo toplevel path
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

_find_command () {
    for c in "$@"; do
        if ! command -v "$c" >/dev/null; then
            return 1
        fi
    done
}

# If the OPAE SIM is already on the PATH then there is no need to build it
# again. Look for a few key programs and build the SIM only if one of them
# is not found.
if _find_command afu_sim_setup; then
    echo ""
    echo "Found OPAE SIM programs on PATH. Not building OPAE SIM."
    echo ""
else
    # default location to clone the repos
    if [ -z "${REPO_PATH}" ]; then
        export REPO_PATH="${OFS_ROOTDIR}"/external
        echo "  REPO_PATH = ${REPO_PATH}"
    fi
    mkdir -p "${REPO_PATH}"

    # default opae-sim repo address
    if [ -z "${OPAE_SIM_REPO}" ]; then
        OPAE_SIM_REPO="https://github.com/OFS/opae-sim"
    fi

    # Default branch to 'master' if the branch variable is not set
    if [ -z "${OPAE_SIM_REPO_BRANCH}" ]; then
        OPAE_SIM_REPO_BRANCH="master"
    fi

    # Default location to clone is $REPO_PATH/opae-sim
    if [ -z "${OPAE_SIM_PATH}" ]; then
        OPAE_SIM_PATH="${REPO_PATH}/opae-sim"
    fi

    # clone opae-sim repo, holding a lock to guarantee that no other builds conflict
    set -x
    "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/setup_git_clone.sh -p -t "${OPAE_SIM_PATH}" \
                    -b "${OPAE_SIM_REPO_BRANCH}" \
                    "${OPAE_SIM_REPO}"

    set +x

    echo "Adding ${OPAE_SIM_PATH}/ase/scripts to PATH..."
    export PATH="${PATH}:${OPAE_SIM_PATH}/ase/scripts"
fi

unset -f _find_command
