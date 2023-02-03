#!/bin/bash

#################################################################################
### The main purpose of this script is to clone opae-sdk and build only the parts
### which are required during the hardware build.  This special effort is helpful
### because the list of those tools does not change very frequently, and hardware
### build environments are often more static in their ability to get dependencies
### installed (as might be needed for unrelated OPAE SDK tool development).

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

# If the OPAE SDK is already on the PATH then there is no need to build it
# again. Look for a few key programs and build the SDK only if one of them
# is not found.
if _find_command PACSign packager afu_json_mgr; then
    echo ""
    echo "Found OPAE SDK programs on PATH. Not building OPAE SDK."
    echo ""
else
    # default location to clone the repos
    if [ -z "${REPO_PATH}" ]; then
        export REPO_PATH="${OFS_ROOTDIR}"/external
        echo "  REPO_PATH = ${REPO_PATH}"
    fi
    mkdir -p "${REPO_PATH}"

    # default opae-sdk repo address
    if [ -z "${OPAE_SDK_REPO}" ]; then
        OPAE_SDK_REPO="https://github.com/OPAE/opae-sdk"
    fi

    # Default branch to 'master' if the branch variable is not set
    if [ -z "${OPAE_SDK_REPO_BRANCH}" ]; then
        OPAE_SDK_REPO_BRANCH="master"
    fi

    # Default location to clone is $REPO_PATH/opae-sdk
    if [ -z "${OPAE_SDK_PATH}" ]; then
        OPAE_SDK_PATH="${REPO_PATH}/opae-sdk"
    fi

    # Default Python virtualenv path
    if [ -z "${BUILDTOOLS_VENV_PATH}" ]; then
        BUILDTOOLS_VENV_PATH="${REPO_PATH}/venv"
    fi

    if [ "${FORCE}" == "1" ]; then
        echo "Removing existing Python venv ( FORCE = ${FORCE} )"
        (set -x; rm -rf "${BUILDTOOLS_VENV_PATH}")
    fi

    echo 'Adding PIM scripts to $PATH for later use...'
    export PATH="${OPAE_SDK_PATH}/platforms/scripts:${PATH}"
    printf "PATH=%q\n" "$PATH"

    # clone opae-sdk repo, holding a lock to guarantee that no other builds conflict
    set -x
    "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/setup_git_clone.sh -p -t "${OPAE_SDK_PATH}" \
                    -s "${OFS_ROOTDIR}"/ofs-common/scripts/common/syn/setup_opae_sdk_venv.sh \
                    -b "${OPAE_SDK_REPO_BRANCH}" \
                    "${OPAE_SDK_REPO}"

    # The setup_oape_sdk_venv.sh invoked by setup_git_clone.sh will create the
    # virtual environment and install OPAE Python tools.
    . "${BUILDTOOLS_VENV_PATH}/bin/activate"
    set +x

    echo 'Extending LD_LIBRARY_PATH so PACSign can rely on the Quartus libcrypto.so...'
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH+$LD_LIBRARY_PATH:}$QUARTUS_ROOTDIR/linux64"
    printf "LD_LIBRARY_PATH=%q\n" "$LD_LIBRARY_PATH"
fi

unset -f _find_command
