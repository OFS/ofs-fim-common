#!/bin/bash

##
## Construct a Python virtual environment from an OPAE SDK clone. This
## script is invoked from setup_git_clone.sh after the OPAE SDK repository
## is cloned while the exclusive lock is still held by setup_git_clone.sh.
## This guarantees that only one thread is updating the venv.
##

# The first argument indicates whether the cloned copy was updated.
DID_SRC_UPDATE=$1

# The path of the cloned repository is passed as the second argument.
OPAE_SDK_PATH="$2"
if [ ! -d "${OPAE_SDK_PATH}" ]; then
    echo "Usage: setup_opae_sdk_venv.sh <opae sdk dir>" 2>&1
    exit 1
fi

# Default Python virtualenv path
if [ -z "${BUILDTOOLS_VENV_PATH}" ]; then
    BUILDTOOLS_VENV_PATH=$(dirname "${OPAE_SDK_PATH}")/venv
fi

_find_command () {
    for c in "$@"; do
        if ! command -v "$c" >/dev/null; then
            return 1
        fi
    done
}

if [ ${DID_SRC_UPDATE} == 0 ] && [ -e "${BUILDTOOLS_VENV_PATH}/bin/activate" ]; then
    . "${BUILDTOOLS_VENV_PATH}/bin/activate"
    if _find_command PACSign packager afu_json_mgr; then
        echo "No updates to ${BUILDTOOLS_VENV_PATH}"
        exit 0
    fi
fi

echo "Preparing virtualenv for OPAE SDK Python-based tools: ${BUILDTOOLS_VENV_PATH}"
# Install PACSign and packager tools for hardware build
if [ ! -e "${BUILDTOOLS_VENV_PATH}/bin/activate" ]; then
    python3 -m venv "${BUILDTOOLS_VENV_PATH}"
fi
. "${BUILDTOOLS_VENV_PATH}/bin/activate"

echo "Installing OPAE SDK Python-based tools..."
python3 -m pip install \
    ${PYPI_CACHE_DIR:+--no-index -f "$PYPI_CACHE_DIR"} \
    "${OPAE_SDK_PATH}/python/packager" \
    "${OPAE_SDK_PATH}/python/pacsign"
