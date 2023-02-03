#!/bin/bash

##
## Setup build variables. The script first loads platfrom-specific variables
## from build_var_setup.sh and then manages some platform-independent configuration.
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

    if [ "X${AFU_WITH_PIM}" != "X" ]; then
        echo ""
        echo "PIM configuration:"
        echo "  PIM_PLATFORM_NAME = ${PIM_PLATFORM_NAME}"
        echo "  PIM_INI_FILE = ${PIM_INI_FILE}"
        echo "  PIM_ROOT_DIR = ${PIM_ROOT_DIR}"
        echo "  AFU_WITH_PIM = ${AFU_WITH_PIM}"
        echo ""
    fi

else
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

    # Reasonable defaults
    if [ "X${USER_CLOCK_FREQS_COMPUTE_TCL_FILE}" == "X" ]; then
        export USER_CLOCK_FREQS_COMPUTE_TCL_FILE=${OFS_ROOTDIR}/ofs-common/scripts/common/syn/user_clock_freqs_compute.tcl
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
                echo "build_setup.sh error: PIM_DEFAULT_AFU not configured!"
                exit 1
            fi
            export AFU_WITH_PIM=${PIM_DEFAULT_AFU}
        fi

        # Check that required variables are defined
        if [ "X${PIM_PLATFORM_NAME}" == "X" ]; then
            echo "build_setup.sh error: PIM_PLATFORM_NAME must be configured when AFU_WITH_PIM is set!"
            exit 1
        fi
        if [ "X${PIM_INI_FILE}" == "X" ]; then
            echo "build_setup.sh error: PIM_INI_FILE must be configured when AFU_WITH_PIM is set!"
            exit 1
        fi
    fi
fi

unset build_var_setup_sh_file
