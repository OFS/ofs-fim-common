# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: MIT

gen_sim_files = "ofs-common/scripts/common/sim/gen_sim_files.sh"
pcie_ss = "ipss/pcie/qip/pcie_ss.ofss"
fim_afu_instances = "src/afu_top/fim_afu_instances.sv"
port_afu_instances = "../ofs-common/src/fpga_family/agilex/port_gasket/afu_main_std_exerciser/fim_compile/port_afu_instances.sv"
pfvf_sim_pkg = "sim/common/pfvf_sim_pkg.sv"
top_cfg_pkg = "src/afu_top/mux/top_cfg_pkg.sv" 
ofs_fim_cfg_pkg = "src/includes/ofs_fim_cfg_pkg.sv" 
tester_tests = "sim/unit_test/csr_test/tester_tests.sv"

