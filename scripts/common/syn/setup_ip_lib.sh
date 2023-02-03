#!/bin/bash

# this sets up the ipss to the path specified by the qsf/tcl file.

# this is an artifact of a stop gap build script.
# since the ofs-dev/ip and ofs-dev/ipss are included in the work directory, there is no need to create the ip_lib
# remove this script and update the .qsys and .tcl files as well as build_fim.sh after the HW team has transitioned to this build infrastructure

ip_lists=("${WORK_DIR}/syn/setup/ip_list.f")

ip_lists+=("${WORK_DIR}/syn/common/setup/ip_list_common.f")

# Is there IP used only during Quartus synthesis?
if [ -e "${WORK_DIR}/syn/setup/ip_list_synth.f" ]; then
    ip_lists+=("${WORK_DIR}/syn/setup/ip_list_synth.f")
fi

for ip_lst in "${ip_lists[@]}"; do
    echo "Processing IP list: ${ip_lst}"
    for ip in `grep -vE '^(\s*$|#)' "${ip_lst}"`; do
        ip_dir=$(dirname -- "${ip}")
        #tgt_dir="${WORK_DIR}/${ip_dir}"
        tgt_dir="${WORK_DIR}/syn/ip_lib/${ip_dir}"
        mkdir -p "${tgt_dir}"

        # Always copy IP files and don't use links back to the source tree.
        # With a link, qsys-generate walks the links back to the source tree and
        # uses the full path to the file when pointing to the IP. This breaks
        # out-of-tree PR generation, which depends on all references being within
        # the work tree.
        rm -f "${tgt_dir}"/${ip}
        cp -f "${OFS_ROOTDIR}"/${ip} "${tgt_dir}"/
    done
done
