# Copyright 2021 Intel Corporation
# SPDX-License-Identifier: MIT

# Makefile
# How this works? 
#   - There is a file file_list.svh file that includes all RTL and TB file inclusions 
#   - You could create two seperate file lists rtl(rtl_lib.svh) and 
#     testbench(test_bench_lib.svh) and include them in file_list.svh 
#   - The RTL owner simply includes the relevant files in the sub-directory that
#     he/her is changing. `ifdef `endif can be used if they need to include
#     files with the same name.
#   - IP files checked out from Quartus only need to be compiled once because
#     they dont change. You need to pre compile the IP before running this make script
#   - Top Level has 3 directories. rtl, sim, syn, scripts
#   - This file resides inside scripts but must be executed from sim. I use a
#     symbolic link inside the sim directory.
#   - To set up VCS and DVE, from the top level dir, run:
#     source scripts/setup.env
#
# How to pre Compile IPs ? 
#   - Copy over synopsys_sim.setup from <IPDIR>/sim/synopsys/vcsmx/
#   - Open sysnopsys_sim.setup and modify path of libraries to <IPDIR>/sim/synopsys/vcsmx/libraries
#   - Run vcsmx_setup.sh QSYS_SIMDIR=<path to IPs sim dir>
#   - e.x. ../rtl/includes/fifos/fifo/sim/synopsys/vcsmx/vcsmx_setup.sh QSYS_SIMDIR=../rtl/includes/fifos/fifo/sim
#
# Test Bench Notes
#   - The case-sensitive string "ERROR" should only be used to print error messages in the log. 
#     There is a perl parser that searches through sim.log and prints if the
#     test passed or failed depending on whether it found "ERROR" in the log.  
#          
# Usage: make compile #compiles RTL/Testbench files
#        make sim # Runs a simulation
#        make view # Opens inter.vpd in DVE to view a waveform

TOP_DIR = ../../../../..

# ALL RTL files and directories visible
# It is ok to have 2 files that define the same module
#RTL_DIR = $(addprefix +incdir+,$(shell find $(TOP_DIR)/src/afu/rtl -type d))
RTL_DIR := $(addprefix +incdir+,$(shell find $(TOP_DIR)/src/includes -type d))
RTL_DIR := $(RTL_DIR) +incdir+$(addprefix +incdir+,$(shell find $(TOP_DIR)/src/fims/d5005/includes -type d))
RTL_DIR := $(RTL_DIR) +incdir+$(TOP_DIR)/src/common
RTL_DIR := $(RTL_DIR) +incdir+$(TOP_DIR)/src/common/ram
RTL_DIR := $(RTL_DIR) +incdir+$(TOP_DIR)/src/common/fifo

# ALL test bench files and direcotries visible
# It is ok to have 2 files that define the same module
#TB_DIR = $(addprefix +incdir+,$(shell find $(TOP_DIR)/verif/AgileX/ac_adp/bbs/block_level/axi_avl_bridge_tb -type d))
TB_DIR = $(TOP_DIR)/verification/common/pfa_master/unit_test

# Test bench top Module
TB_TOP = pfa_master_tb

# Combines TB and RTL directories. 
# This only makes them VISIBLE it doesn't mean they are forced to get compiled
# This just tells the compiler where to look while searching for files
INCDIR := $(RTL_DIR) +incdir+$(TB_DIR)

compile: 
	vlogan -debug_access+all -lca $(INCDIR) -sverilog -timescale=1ps/1ps $(TB_DIR)/file_list.svh  
	@vcs $(TB_TOP) -lca -debug_access+r

sim: 
	./simv -ucli -i $(TB_DIR)/scripts/vpd_dump.key -l sim.log   
	@perl ../scripts/parse.pl   

view: 
	dve -vpd inter.vpd &  

clean: 
	rm -rf DVE* *simv* csrc ucli.key inter.vpd sim.log AN.DB libraries
