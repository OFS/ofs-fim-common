# Copyright 2021 Intel Corporation
# SPDX-License-Identifier: MIT

ifndef WORKDIR
    $(error undefined WORKDIR)
endif

export VIPDIR=$(WORKDIR)/verification/common/pf_vf_mux/vip

export PF_VF_WORKDIR = $(WORKDIR)/verification/common/pf_vf_mux

VCS_OPT = -ntb_opts uvm-1.2 -sverilog -full64 +vcs+lic+wait -l vcs.log +error+100 +incdir+$(PF_VF_WORKDIR)/ +incdir+$(PF_VF_WORKDIR)/env +incdir+$(PF_VF_WORKDIR)/env/tests -f $(PF_VF_WORKDIR)/svt_filelist.f +define+UNIT_TB_PF_VF_MUX -f $(PF_VF_WORKDIR)/rtl_filelist.f -f $(PF_VF_WORKDIR)/verif_filelist.f -timescale=1ns/1fs
VCS_OPT += +define+UVM_DISABLE_AUTO_ITEM_RECORDING
VCS_OPT += +define+DESIGNWARE_HOME=$(DESIGNWARE_HOME)
VCS_OPT += +define+UVM_PACKER_MAX_BYTES=15000000 +define+SVT_AXI_MAX_TDATA_WIDTH=512 +define+SVT_AXI_MAX_TUSER_WIDTH=10
FSDBFILE = ${PF_VF_WORKDIR}/fsdb_dump.tcl
RANDINT = $(shell python -c 'from random import randint; print(randint(1, 2046));')

ifdef TB_CONFIG_1
	VCS_OPT += -debug_access+all +define+NUM_PORT=16 +define+TB_CONFIG_1
	TEST_DIR = results/$(TESTNAME)_CONFIG_1
endif 

ifdef TB_CONFIG_2
	VCS_OPT += -debug_access+all +define+NUM_PORT=24 +define+TB_CONFIG_2
	TEST_DIR = results/$(TESTNAME)_CONFIG_2
endif

ifdef TB_CONFIG_3
	VCS_OPT += -debug_access+all +define+NUM_PORT=32 +define+TB_CONFIG_3 +define+RANDOM_VF=$(RANDINT)
	TEST_DIR = results/$(TESTNAME)_CONFIG_3
endif

ifdef TB_CONFIG_4
	VCS_OPT += -debug_access+all +define+NUM_PORT=2048 +define+TB_CONFIG_4 +define+SVT_AXI_MAX_NUM_MASTERS_450 +define+SVT_AXI_MAX_NUM_SLAVES_450
	TEST_DIR = results/$(TESTNAME)_CONFIG_4
endif

ifndef SEED
    SIMV_OPT += +ntb_random_seed_automatic
else
    SIMV_OPT += +ntb_random_seed=$(SEED)
endif


ifdef DUMP
	   VCS_OPT += +define+DUMP
endif

ifdef DUMP_FSDB
	export VERDI_HOME=/p/hdk/rtl/cad/x86-64_linux30/synopsys/verdi3/R-2020.12-SP1-1/
	VCS_OPT += -kdb
	SIMV_OPT += -ucli -i $(FSDBFILE)
endif


ifeq ($(TESTNAME),pf_vf_mux_master_axi_write_invalid_test)  
	VCS_OPT += +define+INVALID_PF_VF
endif

ifeq ($(TESTNAME),pf_vf_mux_master_axi_reset_in_middle_test)  
	VCS_OPT += +define+RESET_PF_VF
endif

ifeq ($(TESTNAME),pf_vf_mux_slave_axi_reset_in_middle_test)  
	VCS_OPT += +define+RESET_PF_VF
endif

ifeq ($(TESTNAME),pf_vf_mux_tuser_vendor_toggle_test)  
	VCS_OPT += +define+COVER_USER_VENDOR
endif

#=========================================================================
# Below define is used for disabling scoreboard incase of error scenarios
#=========================================================================
ifeq ($(TESTNAME),pf_vf_mux_master_bp_test)
	VCS_OPT += +define+ERR_CASE
else ifeq ($(TESTNAME),pf_vf_mux_master_fifo_error_test)
	VCS_OPT += +define+ERR_CASE
else ifeq ($(TESTNAME),pf_vf_mux_master_axi_reset_in_middle_test)
	VCS_OPT += +define+ERR_CASE
else ifeq ($(TESTNAME),pf_vf_mux_slave_sequential_backpressure_test)
	VCS_OPT += +define+ERR_CASE
else ifeq ($(TESTNAME),pf_vf_mux_slave_simultaneous_backpressure_test)
	VCS_OPT += +define+ERR_CASE
else ifeq ($(TESTNAME),pf_vf_mux_slave_axi_reset_in_middle_test)
	VCS_OPT += +define+ERR_CASE
else ifeq ($(TESTNAME),pf_vf_mux_slave_fifo_error_test)
	VCS_OPT += +define+ERR_CASE
endif

ifdef COV
    VLOG_OPT += +define+COV -cm line+cond+fsm+tgl+branch -cm_name $(TEST_DIR) -cm_dir simv.vdb
    VCS_OPT  += -cm line+cond+fsm+tgl+branch -cm_name $(TEST_DIR) -cm_dir simv.vdb
    SIMV_OPT += -cm line+cond+fsm+tgl+branch -cm_name $(TESTNAME) -cm_dir regression.vdb
endif

SIMV_OPT += -cm_test pf_vf_mux -l runsim.log 
SIMV_OPT += +UVM_TESTNAME=$(TESTNAME) 

build_vip:
	mkdir -p vip/
	@$(DESIGNWARE_HOME)/bin/dw_vip_setup -path vip/ -add axi_system_env_svt -svlog

vcs: 
	mkdir -p $(TEST_DIR) && cd $(TEST_DIR) && vcs $(VCS_OPT) $(PF_VF_WORKDIR)/top_tb.sv

run_test:
	cd $(TEST_DIR) && ./simv $(SIMV_OPT) 

run: vcs run_test
