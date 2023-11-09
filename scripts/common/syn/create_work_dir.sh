#!/bin/bash
# Copyright (C) 2021-2023 Intel Corporation
# SPDX-License-Identifier: MIT

# This scripts duplicates the tree in work directory and symlink the files
# default work directory is "work"
# WORK_DIR can be a name or a path.
#   - if name, this script will convert it to a path under OFS_ROOTDIR
#   - if it's a path, this script will check to ensure the path doesn't point
#     to a directory lower than $OFS_ROOTDIR/WORK_DIR


#check for $OFS_ROOTDIR and set to cloned repo toplevel path
if [ -z "${OFS_ROOTDIR}" ]; then
    echo "Warning: OFS_ROOTDIR is not set"
    echo "Deriving OFS_ROOTDIR from git clone directory..."
    # check if in a cloned/downloaded repo"
    if ! OFS_ROOTDIR="$(git rev-parse --show-toplevel)"; then
        #not in git cloned repo and OFS_ROOTDIR not set: error out.
        echo "Error: OFS_ROOTDIR not set and cannot derive toplevel path from git command" 1>&2
        echo "       Please set OFS_ROOTDIR" 1>&2
        exit 1
    fi
    export OFS_ROOTDIR
    echo "OFS_ROOTDIR now set to: ${OFS_ROOTDIR}"
fi

#set default work directory
if [ -z "${WORK_DIR}" ]; then
    WORK_DIR="work"
fi

usage() {
    echo "Usage: ${SCRIPTNAME} [-f] [-k] [-c] <work dir>" 1>&2
    echo "" 1>&2
    echo "  -c     copy work directory (not symlink)"
    echo "  -f     Force (overwrite target)." 1>&2
    echo "  -k     Keep (build again in existing target)." 1>&2
    echo "  -w     Work directory (default directory: work)." 1>&2
    echo "" 1>&2
}

parse_args() {

    local OPTIND
    while getopts "hfkc" opt; do
        case "${opt}" in
            h)
                usage
                exit 0
                ;;
            c)
                COPY_WORK=1
                echo "Option enabled: 'COPY' - Copy files to work directory vs symlink"
                ;;
            f)
                FORCE=1
                echo "Option enabled: 'FORCE' - overwriting existing targets"
                ;;
            k)
                KEEP=1
                echo "Option enabled: 'KEEP' - rebuild in existing targets"
                ;;
            \?)
                echo "Invalid Option: -$OPTARG" 1>&2
                echo "" 1>&2
                usage
                exit 1
                ;;
            *)
                usage
                exit 1
                ;;
        esac
    done

    shift $((OPTIND-1))
    if [ -n "${1}" ]; then
        if [[ ${1} =~ ^\-.* ]]; then
            usage
            exit 1
        fi
        WORK_DIR="${1}"
    fi
}


parse_args "$@"

# reply timeout in seconds
WAIT_SECS=20

if [ -z ${COPY_WORK} ]; then
    COPY_WORK="0"
fi

if [ -z ${FORCE} ]; then
    FORCE="0"
fi

if [ -z ${KEEP} ]; then
    KEEP="0"
fi

if [ ${COPY_WORK} == '1' ]; then
    CP_FLAGS=""
else
    CP_FLAGS="--symbolic-link"
fi

echo "*** Specified WORK directory: ${WORK_DIR}"

#check if WORK_DIR is a path or name
if [ "$(dirname "${WORK_DIR}")" == "." ]; then
    #WORK_DIR is a name. Prepend $OFS_ROOTDIR
    WORK_DIR="${OFS_ROOTDIR}/${WORK_DIR}"
else
    # WORK_DIR is a path. Check to ensure WORK_DIR is not lower than clone_workspace/<work dir name>
    _relpath="$(realpath --relative-base "$OFS_ROOTDIR" -m "$WORK_DIR")"
    # realpath --relative-base prints an absolute path if target directory
    # falls outside given base, so if there's a leading '/', workdir is fine.
    if [[ ${_relpath##/*} ]]; then
        # The work directory is *inside* the OFS_ROOTDIR, which is permitted
        # only if it is in the top-level directory; any '/' contained in the
        # relative path means it is not. If ALLOW_PROJ_IN_OFS_ROOTDIR is set
        # the script is allowed to proceed. This variable is set for a
        # special case when configuring a project to generate IP for simulation.
        # The override should be used sparingly. Work trees inside the
        # source tree are likely to have missing pieces to avoid recursive
        # copies.
        if [[ ! ${_relpath##*/*} && -z "${ALLOW_PROJ_IN_OFS_ROOTDIR}" ]]; then
            echo "ERROR: Cannot create work directory in a lower path than ${OFS_ROOTDIR}" 1>&2
            echo "       Valid path example: ${OFS_ROOTDIR}/$(basename "${WORK_DIR}")" 1>&2
            echo ""
            exit 1
        fi
    fi
    unset _relpath
fi


if [ -d "${WORK_DIR}" ]; then
    echo "${WORK_DIR} exists"
    if [ ${KEEP} == '1' ]; then
        echo "Continuing to compile in the existing directory ${WORK_DIR}"
        # Update only missing files
        CP_FLAGS="$CP_FLAGS --no-clobber --verbose"
    elif [ ${FORCE} == '1' ]; then
        echo "Deleting ${WORK_DIR}"
        rm -rf "${WORK_DIR}"
    else
        echo ""
        echo "Please enter response before script terminates in ${WAIT_SECS} seconds"
        echo "Are you sure you want to compile in the existing dir?"
        echo "y: yes,  n: no,  f: force (delete and recreate work dir)"

        # timeout or incorrect value will exit.
        read -r -t ${WAIT_SECS}
        case ${REPLY} in
            n)
                echo "Aborting, Please user -f option to overwrite" 1>&2
                exit 5
                ;;
            y)
                echo "Continuing to compile in the existing directory ${WORK_DIR}"
                CP_FLAGS="$CP_FLAGS --no-clobber --verbose"
                ;;
            f)
                echo "removing ${WORK_DIR}"
                rm -rf "${WORK_DIR}"
                ;;
            *)
                echo "Invalid reply or timeout reached, aborting script" 1>&2
                exit 4
                ;;
        esac
    fi
fi


echo " Creating ${WORK_DIR}"
if [ "${COPY_WORK}" == "1" ]; then
    echo " Copying files..."
else
    echo " Symlinking files..."
fi
echo "This may take a couple of minutes..."

mkdir -p "${WORK_DIR}/ofs-common"

# Construct a working tree from the top-level directories, avoiding some paths
# irrelevant to this new worktree (such as hidden files, other worktrees,
# external/supplemental git clones, etc.).
for dir in "$OFS_ROOTDIR"/* "$OFS_ROOTDIR"/ofs-common/*; do
    if [[ ! -d $dir ]]; then
        # Do not need to link to non-directories at the repo top level.
        continue
    elif [[ $(basename "$dir") =~ ofs-common|external|sim|verification|license|eval_scripts ]]; then
        # These directories are not used in a build workspace, so skip them.
        continue
    elif [[ -d $dir/ofs-common ]]; then
        # A directory containing an ofs-common directory indicates another
        # workspace. Do not unnecessarily link its files into this one.
        continue
    fi

    # In the unusual case where the copy is inside the OFS_ROOTDIR, skip
    # the top-level directory containing the copy. The calling script is
    # expected to set ALLOW_PROJ_IN_OFS_ROOTDIR to that directory.
    if [[ -n "${ALLOW_PROJ_IN_OFS_ROOTDIR}" && $(basename "$dir") == "${ALLOW_PROJ_IN_OFS_ROOTDIR}" ]]; then
        echo "  Skipping ${dir} to avoid recursive copy."
        continue
    fi

    #relative path under WORK_DIR
    rel_dir=$(dirname "${dir#"$OFS_ROOTDIR"}")
    cp -r $CP_FLAGS "${dir}" "${WORK_DIR}/${rel_dir}"
done

# Contruct a working tree for user specified sr_afu
if [[ -v OFS_BUILD_TAG_SR_AFU ]]; then
    #relative path under WORK_DIR
    mkdir -p "${WORK_DIR}/sr_afu"
    src_dir=$(realpath "${OFS_BUILD_TAG_SR_AFU}")
    if [ ! -f "$src_dir" ]; then
        echo "ERROR: SR AFU sources.tcl not found in afu dir ${OFS_BUILD_TAG_SR_AFU}" 1>&2
        echo ""
        exit 1
    fi

    cp -r $CP_FLAGS "$src_dir" "${WORK_DIR}"
fi

if [[ -v OFS_BUILD_TAG_PR_FLOORPLAN ]]; then
    #Create a new folder WORK_DIR/syn/user_settings/
    mkdir -p "${WORK_DIR}/syn/user_settings/"
    rel_file="syn/user_settings/$(basename "${OFS_BUILD_TAG_PR_FLOORPLAN}")"
    src_file=$(realpath "${OFS_BUILD_TAG_PR_FLOORPLAN}")
    if [ ! -f "$src_file" ]; then
        echo "ERROR: PR assignment file ${OFS_BUILD_TAG_PR_FLOORPLAN} not found" 1>&2
        echo ""
        exit 1
    fi

    cp $CP_FLAGS "$src_file" "${WORK_DIR}/${rel_file}"
fi
echo "Done setting up work directory (${WORK_DIR})"
