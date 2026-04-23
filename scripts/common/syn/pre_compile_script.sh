#!/bin/bash
# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: MIT

##
## This script is run in the middle of the setup stage. It disables features
## removed on the command line with tags, e.g. n6001:no_hssi,no_ddr4.
##
## The script is run in the project directory.
##

# Loop over all features that can be disabled
for tag in DDR4 HPS HSSI PMCI PR USER_CLK REMOTE_STP JTAG_PR_STP; do
    # Construct a tag variable name that can be tested in the shell
    test_tag="OFS_BUILD_TAG_NO_${tag}"
    if [ ! -z ${!test_tag} ]; then
        # OFS_BUILD_TAG_NO_<tag> is defined. Disable the feature by commenting
        # out any instances of INCLUDE_<tag> macros in QSF files.
        echo "Disabling INCLUDE_${tag}"
        sed -i -e "/set_global_assignment.*VERILOG_MACRO.*INCLUDE_${tag}/s/^[^#]/# &/" *.qsf
    fi
done

unset test_tag
