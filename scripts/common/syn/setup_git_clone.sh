#!/bin/bash
# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: MIT

##
## Thread-safe clone of a git repository. The script holds a lock during
## the cloning in case multiple processes are requesting the repository.
## Because it is thread-safe, the script can be used to clone a repository
## that is shared by multiple builds.
##
## A setup script, passed as an argument, can also be run after the clone
## while the lock is held. This is used, for example, to configure Python
## libraries after a successful clone.
##

usage() {
  echo "" 1>&2
  echo "Usage: $0 [-f] [-p] -t <tgt> [-b <branch>] [-s <post-clone script>] <repository path>" 1>&2
  echo "" 1>&2
  echo "  The target directory into which the repository will be cloned must" 1>&2
  echo "  be specified." 1>&2
  echo "" 1>&2
  echo "  The repository is only cloned if the target directory does not already" 1>&2
  echo "  exist or if -f is set. If -p is set, git pull is executed if the clone" 1>&2
  echo "  is already present." 1>&2
  echo "" 1>&2
  exit 1
}

FORCE=0
PULL=0
TGT=""
BRANCH=""
POST_CLONE_SCRIPT=""

while getopts "fpt:b:s:" OP; do
  case "${OP}" in
    f)
      FORCE=1
      ;;
    p)
      PULL=1
      ;;
    t)
      TGT="${OPTARG}"
      ;;
    b)
      BRANCH="${OPTARG}"
      ;;
    s)
      POST_CLONE_SCRIPT="${OPTARG}"
      ;;
    ?)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

SRC_REPO="${1}"
if [ "$SRC_REPO" == "" ]; then
  echo "Source repository path not specified!" 1>&2
  usage
fi

if [ "$TGT" == "" ]; then
  echo "Target path not specified!" 1>&2
  usage
fi

LOCKFILE=$(dirname "${TGT}")/lockfile

# Abort on error. When the lock is held, this will also trigger the trap
# the removes the lock.
set -e

# Loop until this process gets a lock for the target, guaranteeing that it is
# the only process currently attempting to clone.
trips=0
while true; do
  if ( set -o noclobber; echo "`hostname` pid $$" > "${LOCKFILE}") 2> /dev/null; then
    # Remove the lockfile and the new clone target if anything goes wrong
    trap 'echo "Aborting git clone" 2>&1; rm -rf "$LOCKFILE" "$TGT"; exit 1' INT TERM

    # This will track whether new sources were pulled
    DID_SRC_UPDATE=0

    if [ -d "${TGT}" ] && [ ${FORCE} -eq 0 ]; then
      # Clone present already. Do a git pull?
      if [ -d "${TGT}"/.git ] && [ ${PULL} -ne 0 ]; then
        (set -x; cd "${TGT}"; git fetch)
        # Is the local copy stale?
        if [ $(git --git-dir="${TGT}"/.git rev-parse HEAD) != $(git --git-dir="${TGT}"/.git rev-parse '@{u}') ]; then
          DID_SRC_UPDATE=1
          (set -x; cd "${TGT}"; git pull)
        fi
      else
        echo "${TGT} already present."
      fi
    else
      rm -rf "${TGT}"
      DID_SRC_UPDATE=1
      if [ "${BRANCH}" == "" ]; then
        (set -x; git clone "${SRC_REPO}" "${TGT}")
      else
        (set -x; git clone -b "${BRANCH}" "${SRC_REPO}" "${TGT}")
      fi
    fi

    # The clone worked. Just cleanup lockfile on exit.
    trap 'echo "Aborting post-clone script" 2>&1; rm -rf "$LOCKFILE"; exit 1' INT TERM

    if [ "${POST_CLONE_SCRIPT}" != "" ]; then
      echo "Executing post-clone script: ${POST_CLONE_SCRIPT}"
      ${POST_CLONE_SCRIPT} ${DID_SRC_UPDATE} "${TGT}"
    fi

    rm -f "${LOCKFILE}"
    trap - INT TERM
    break
  else
    # Failed to get the lock
    if [ $trips -eq 0 ]; then
      echo "Waiting for the ${LOCKFILE} to be released..."
    fi

    # After 5 minutes assume the process holding the lock has failed
    sleep 1
    if [ $trips -eq 300 ]; then
      echo "Waited for 5 minutes. Clearing the lock..."
      rm -f "${LOCKFILE}"
      trips=0
    fi

    trips=$((trips+1))
  fi
done
