#!/bin/bash
# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: MIT

#################################################################################
### Clone ofs-platform-afu-bbb into the build environment.
###

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

# default location to clone the repos
if [ -z "${REPO_PATH}" ]; then
    export REPO_PATH="${OFS_ROOTDIR}"/external
    echo "  REPO_PATH = ${REPO_PATH}"
fi
mkdir -p "${REPO_PATH}"

# default ofs-platform-afu-bbb repo address
if [ -z "${OFS_PLATFORM_AFU_BBB_REPO}" ]; then
    OFS_PLATFORM_AFU_BBB_REPO="https://github.com/OFS/ofs-platform-afu-bbb"
fi

# Default branch to 'master' if the branch variable is not set
if [ -z "${OFS_PLATFORM_AFU_BBB_REPO_BRANCH}" ]; then
    OFS_PLATFORM_AFU_BBB_REPO_BRANCH="master"
fi

# Default location to clone is $REPO_PATH/ofs-platform-afu-bbb
if [ -z "${OFS_PLATFORM_AFU_BBB}" ]; then
    export OFS_PLATFORM_AFU_BBB="${REPO_PATH}/ofs-platform-afu-bbb"
    echo "Using cloned OFS_PLATFORM_AFU_BBB=${OFS_PLATFORM_AFU_BBB}"
fi

# clone PIM repo, holding a lock to guarantee that no other builds conflict
"${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/setup_git_clone.sh -p -t "${OFS_PLATFORM_AFU_BBB}" \
                -b "${OFS_PLATFORM_AFU_BBB_REPO_BRANCH}" \
                "${OFS_PLATFORM_AFU_BBB_REPO}"
