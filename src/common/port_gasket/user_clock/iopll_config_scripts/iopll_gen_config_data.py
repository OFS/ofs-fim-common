#!/usr/bin/python
# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

""" Generate a C header file containing IOPLL config data """


import subprocess
import sys


def get_pll_settings(ref_freq, freq):
    """ Generate pll config values for a given desired frequency """
    ret = subprocess.call(["quartus_sh", "-t",
                           "generate_pll_settings_s10.tcl",
                           str(ref_freq) + ".0", str(freq) + ".0"])
    if ret:
        sys.exit(ret)

    with file("pll_config.bin") as file_handle:
        config_string = file_handle.read()

    return config_string.rstrip('\n')


def format_config(config_string):
    """ Create a C data structure with pll config values """
    return ('\t{{ {0:d}, {1:#x}, {2:#x}, {3:#x}, {4:#x}, {5:#x}, '
            '{6:#x}, {7:#x} }}').format(
            *list([int(x) for x in config_string.split()]))


def file_header(file_handle, ref_freq, min_freq, max_freq):
    """ Add the C header file definitions to the top of the header file """
    file_handle.write("#define IOPLL_MIN_FREQ\t{0:d}\n".format(min_freq))
    file_handle.write("#define IOPLL_MAX_FREQ\t{0:d}\n\n".format(max_freq))

    file_handle.write("struct iopll_config {\n")
    file_handle.write("\tunsigned int pll_freq_khz;\n")
    file_handle.write("\tunsigned int pll_m;\n")
    file_handle.write("\tunsigned int pll_n;\n")
    file_handle.write("\tunsigned int pll_c1;\n")
    file_handle.write("\tunsigned int pll_c0;\n")
    file_handle.write("\tunsigned int pll_lf;\n")
    file_handle.write("\tunsigned int pll_cp;\n")
    file_handle.write("\tunsigned int pll_rc;\n")
    file_handle.write("};\n\n")

    file_handle.write("// Reference frequency: {0:d}MHz\n".format(ref_freq))
    file_handle.write("struct iopll_config iopll_freq_config[] = {\n")
    for freq in range(0, min_freq):
        file_handle.write("\t{{ 0 }}, // Freq {0:d} not configured\n".
                                               format(freq))


def file_footer(file_handle):
    """ Close out the iopll_config array of data structures """
    file_handle.write("};\n")


###########################################################################
#
# MAIN SCRIPT
#
###########################################################################

if __name__ == "__main__":

    REF_FREQ = 100
    MIN_FREQ = 10
    MAX_FREQ = 600
    C_HEADER = "user_clk_iopll_freq.h"

    with open(C_HEADER, "w") as iopll_config:
        file_header(iopll_config, REF_FREQ, MIN_FREQ, MAX_FREQ)

        for frequency in range(MIN_FREQ, MAX_FREQ + 1):
            config = get_pll_settings(REF_FREQ, frequency)
            init_struct = format_config(config)
            iopll_config.write(init_struct +
                               ("\n" if (frequency == MAX_FREQ)
                                else ",\n"))

        file_footer(iopll_config)
