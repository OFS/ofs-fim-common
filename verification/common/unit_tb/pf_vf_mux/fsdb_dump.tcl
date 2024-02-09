# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: MIT

fsdbDumpvars 0 "top_tb"
fsdbDumpvars +struct
fsdbDumpvars +all
fsdbDumpvars +mda
fsdbDumpvars +packedmda
fsdbDumpvars +fsdbfile+dump.fsdb 
run
