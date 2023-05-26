#!/bin/bash
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Setup build variables. The script first loads platfrom-specific variables
## from build_var_setup.sh and then manages some platform-independent configuration.
##
## The script takes the same two <board variant> [<work dir>] arguments as
## build_fim.sh. The work directory becomes "${OFS_ROOTDIR}/work" when
## not specified.
##

# Load project-specific variables
build_var_setup_sh_file=${OFS_ROOTDIR}/syn/scripts/build_var_setup.sh

if [ "X${BUILD_VAR_SETUP_COMPLETE}" == "X1" ]; then

    # Second time the script is run -- just print variables by calling build_var_setup.sh
    source ${build_var_setup_sh_file} | tee /dev/null

    if [ "X${BUILD_ROOT_REL}" != "X" ]; then
        echo "  BUILD_ROOT_REL = ${BUILD_ROOT_REL}"
    fi

    if [ "X${REPO_PATH}" != "X" ]; then
        echo "  REPO_PATH = ${REPO_PATH}"
    fi

    echo ""
    echo "PIM configuration:"
    echo "  PIM_PLATFORM_NAME = ${PIM_PLATFORM_NAME}"
    echo "  PIM_INI_FILE = ${PIM_INI_FILE}"
    echo "  PIM_ROOT_DIR = ${PIM_ROOT_DIR}"
    if [ "X${AFU_WITH_PIM}" != "X" ]; then
        echo "  AFU_WITH_PIM = ${AFU_WITH_PIM}"
    fi
    echo ""

else
    ##
    ## Consume the board path and variant option
    ##

    # Remove the optional trailing colon and variant string.
    export OFS_BOARD_PATH="${1%%:*}"
    echo ">>> OFS Board Path = ${OFS_BOARD_PATH}"
    if [ ! -d "${OFS_ROOTDIR}/syn" ]; then
        echo "OFS platform path ${OFS_ROOTDIR}/syn not found"
        exit 1
    fi

    # Retain the core board product that is being targeted for compilation
    OFS_BOARD_CORE="${1#*syn\/}"
    export OFS_BOARD_CORE="${OFS_BOARD_CORE%%\/*}"
    echo ">>> OFS Board Core = ${OFS_BOARD_CORE}"

    # Extract the variant string (which includes leading colon), then remove the
    # leading colon. If no variant was specified, this results in an empty string.
    OFS_BOARD_VARIANT="${1#$OFS_BOARD_PATH}"
    OFS_BOARD_VARIANT="${OFS_BOARD_VARIANT#:}"
    # No sanity checking of the value can be done at this point. It's up to the
    # board-specific handling scripts to use or abuse the value as they want.
    export OFS_BOARD_VARIANT

    # Split the variant string into comma-delimited components. These are then
    # converted into build "tags" which can be used later through a corresponding
    # environment variable.  The primary use is for simple boolean flags, with the
    # tag variable not set meaning 'false' and tag variable set to "1" for true.
    #
    # A tag may optionally accept a string value which is exported in its tag
    # variable rather than using the default value of "1".
    #
    # Example results:
    #
    #   syn/build_top.sh n6000 =>
    #     (no $OFS_BUILD_TAG_* variables exported)
    #
    #   syn/build_top.sh n6000:flat =>
    #     OFS_BUILD_TAG_FLAT=1
    #
    #   syn/build_top.sh n6000:no_hssi =>
    #     OFS_BUILD_TAG_NO_HSSI=1
    #
    IFS=, read -r -a _OFS_BUILD_TAGS <<< "$OFS_BOARD_VARIANT"
    for t in "${_OFS_BUILD_TAGS[@]}"; do
        # Everything up to the first '=' character is the tag's name.
        _tag_key="${t%%=*}"
        # Anything following the tag name and '=' should be the value.
        _tag_value="${t#$_tag_key}"
        _tag_value="${_tag_value#=}"

        # Make the key upper-case to normalize the variable name, then set it to
        # "1" for the usual case of string not provided on command line.
        export "OFS_BUILD_TAG_${_tag_key^^}=${_tag_value:-1}"
    done
    unset _OFS_BUILD_TAGS _tag_key _tag_value

    #################################
    ###   Set WORK directory
    ###   checks on WORK directory done in work dir creation script
    if [ -z "${2}" ]; then
        export WORK_DIR="${OFS_ROOTDIR}/work"
    else
        if [ "$(dirname ${2})" == "." ]; then
            # Passing in a name, prepend OFS_ROOTDIR to the path
            export WORK_DIR="${OFS_ROOTDIR}/${2}"
        else
            # Passing in a path, us as-is
            export WORK_DIR="${2}"
        fi
    fi


    ##
    ## Source the board-specific setup file
    ##
    echo ""
    echo "Setting up build variables"
    echo "source ${build_var_setup_sh_file}"
    source ${build_var_setup_sh_file} 
    error_code=${?}
    if [ "${error_code}" != "0" ]; then
        echo "Error sourcing ${build_var_setup_sh_file}" 1>&2
        echo "Exit code: ${error_code}" 1>&2
        exit 1
    fi

    if [ "X${WORK_SYN_TOP_PATH}" == "X" ]; then
        echo "Error: expected WORK_SYN_TOP_PATH to be defined"
        exit 1
    fi

    export SYN_COMMON_SCRIPTS_PATH="${OFS_ROOTDIR}"/ofs-common/scripts/common/syn

    # Relative path from the Quartus build directory to the root of the
    # build tree. The build tree has links to all sources. A relative
    # path simplifies creation of Quartus archives, used by the PR flow.
    if [ -d "${WORK_SYN_TOP_PATH}" ]; then
        export BUILD_ROOT_REL=$(realpath --relative-to="${WORK_SYN_TOP_PATH}" "${WORK_DIR}")
    fi
        echo "BUILD_ROOT_REL is $BUILD_ROOT_REL"

    # Directory into which external repositories will be cloned. We use a
    # build-private location to avoid conflicts between builds that depend
    # on different branches of these repositories. Using separate trees also
    # avoids races during parallel builds.
    if [ "X${REPO_PATH}" == "X" ]; then
        export REPO_PATH="${OFS_ROOTDIR}"/external
    fi

    # Path in which the PIM will be constructed, along with an AFU
    export PIM_ROOT_DIR=${WORK_SYN_TOP_PATH}/afu_with_pim

    # If an AFU is being constructed with the PIM, OPAE SDK is required
    if [ "X${AFU_WITH_PIM}" != "X" ]; then
        export ENA_OPAE_SDK_SETUP_FOR_FIM=1
        export ENA_OPAE_SDK_SETUP_FOR_PR=1

        if [ "${AFU_WITH_PIM}" == "1" ]; then
            # Normally, AFU_WITH_PIM is set to a file containing a list of sources.
            # When it is just "1", use the default.
            if [ "X${PIM_DEFAULT_AFU}" == "X" ]; then
                echo "build_var_setup_common.sh error: PIM_DEFAULT_AFU not configured!"
                exit 1
            fi
            export AFU_WITH_PIM=${PIM_DEFAULT_AFU}
        fi

        # Check that required variables are defined
        if [ "X${PIM_PLATFORM_NAME}" == "X" ]; then
            echo "build_var_setup_common.sh error: PIM_PLATFORM_NAME must be configured when AFU_WITH_PIM is set!"
            exit 1
        fi
        if [ "X${PIM_INI_FILE}" == "X" ]; then
            echo "build_var_setup_common.sh error: PIM_INI_FILE must be configured when AFU_WITH_PIM is set!"
            exit 1
        fi
    fi
fi

unset build_var_setup_sh_file
