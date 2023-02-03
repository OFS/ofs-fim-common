#!/bin/bash

# create sdc file for PR 
quartus_sta -t ${CREATE_SDC_FOR_PR_COMPILE_TCL_FILE}

# fix sdc (get_combs gets created but need to be removed as it will cause an error in the sdc file)
${FIX_PR_SDC_PY_FILE} --sdc ${WORK_SDC_FOR_PR_COMPILE_SDC_FILE}

# User clock setup. The FIM build may have set up the clock already. Only invoke
# the script here if needed.
if [ "${ENA_USER_CLOCK_FOR_PR}" == "1" ]; then
    if [[ "${WORK_USER_CLOCK_DEFS_TCL_FILE}" != "" && ! -f "${WORK_USER_CLOCK_DEFS_TCL_FILE}" ]]; then
        if [ "${SETUP_USER_CLOCK_FOR_PR_TCL_FILE}" != "" ]; then
            quartus_sta -t ${SETUP_USER_CLOCK_FOR_PR_TCL_FILE}
        fi
    fi
fi
