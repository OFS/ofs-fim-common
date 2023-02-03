#!/bin/bash

# This scripts duplicates the tree in work directory and symlink the files
# default work directory is "work"
# requirement is that the work directory must start with "work" e.g. work2
# WORK_DIR can be a name or a path.
#   - if name, this script will convert it to a path under OFS_ROOTDIR
#   - if it's a path, this script will check to ensure the path doesn't point
#     to a directory lower than $OFS_ROOTDIR/WORK_DIR


#check for $OFS_ROOTDIR and set to cloned repo toplevel path
if [ -z "${OFS_ROOTDIR}" ]; then
    echo "Warning: OFS_ROOTDIR is not set"
    echo "Deriving OFS_ROOTDIR from git clone directory..."
    OFS_ROOTDIR="$(git rev-parse --show-toplevel)"
    # check if in a cloned/downloaded repo"
    if [ ${?} != "0" ]; then
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

echo "*** Specified WORK directory: ${WORK_DIR}"
#check if work directory begins with "work"
if [[ $(basename "${WORK_DIR}") != "work"* ]]; then
    echo ""
    echo "Error: work directory name must start with 'work'" 1>&2
    echo "       e.g. work2_d5005"
    echo ""
    exit 1
fi

#check if WORK_DIR is a path or name
if [ "$(dirname "${WORK_DIR}")" == "." ]; then
    #WORK_DIR is a name. append $OFS_ROOTDIR
    WORK_DIR="${OFS_ROOTDIR}/${WORK_DIR}"
else
    # WORK_DIR is a path. Check to ensure WORK_DIR is not lower than ofs-dev/<work dir name>  (or if git project  name changed, then use the new name)
    if [[ "${WORK_DIR}" == *"$(basename "${OFS_ROOTDIR}")"* ]] && [[ "$(basename "$(dirname "${WORK_DIR}")")" != "$(basename "${OFS_ROOTDIR}")" ]]; then
        echo "ERROR: Cannot create work directory in a lower path than ${OFS_ROOTDIR}" 1>&2
        echo "       Valid path example: ${OFS_ROOTDIR}/$(basename "${WORK_DIR}")" 1>&2
        echo ""
        exit 1
    fi
fi


if [ -d "${WORK_DIR}" ]; then
    echo "${WORK_DIR} exists"
    if [ ${KEEP} == '1' ]; then
        echo "Continuing to compile in the existing directory ${WORK_DIR}"
        exit 0
    elif [ ${FORCE} == '1' ]; then
        echo "Deleting ${WORK_DIR}"
        rm -rf "${WORK_DIR}"
    else
        echo ""
        echo "Please enter response before script terminates in ${WAIT_SECS} seconds"
        echo "Are you sure you want to compile in the existing dir?"
        echo "y: yes,  n: no,  f: force (resync work dir)"

        # timeout or incorrect value will exit.
        read -r -t ${WAIT_SECS}
        case ${REPLY} in
            n)
                echo "Aborting, Please user -f option to overwrite" 1>&2
                exit 5
                ;;
            y)
                echo "Continuing to compile in the existing directory ${WORK_DIR}"
                exit 0
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

# Need to create a working tree, except it should avoid some paths which are
# irrelevant to this new worktree (such as hidden files, other worktrees,
# external/supplemental git clones, etc.). Start by getting a list of the
# directories which *should* be included in the new tree:
dirtree=()
while IFS='' read -r dir; do
    dirtree+=("$dir")
done < <(find "${OFS_ROOTDIR}"/* "${OFS_ROOTDIR}"/ofs-common/* \
              -maxdepth 0 -type d \
              -not -name ofs-common \
              -not -path "${OFS_ROOTDIR}/.*" \
              -not -path "${OFS_ROOTDIR}/external" \
              -not -path "${OFS_ROOTDIR}/work*" \
              -not -path "${OFS_ROOTDIR}/verification")

mkdir -p "${WORK_DIR}" "${WORK_DIR}/ofs-common"

# Now create a copy/symlink tree for each of the subtrees which were selected:
for dir in "${dirtree[@]}"; do
    #relative path under WORK_DIR
    rel_dir="${dir#${OFS_ROOTDIR}}"
    if [ ${COPY_WORK} == '1' ]; then
        cp -r "${dir}" "${WORK_DIR}${rel_dir}"
    else
        cp -r --symbolic-link "${dir}" "${WORK_DIR}${rel_dir}"
    fi
done

echo "Done setting up work directory (${WORK_DIR})"
