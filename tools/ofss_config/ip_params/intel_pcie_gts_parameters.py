# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: MIT

import subprocess
import sys

# SM supports at most 4 PFs
max_num_pfs = 4

default_component_params = {
    "g3_pld_clkfreq_user_hwtcl": "250MHz",
    "axi_lite_clk_freq_user_p0_hwtcl": 100,
    "core16_enable_multi_func_hwtcl": 1,
    "core16_enable_sriov_hwtcl": 0,
    "core16_ctrl_shadow_en_hwtcl": 1,
    "core16_comp_timeout_en_hwtcl": 1,
    "core16_flr_cap_user_hwtcl": 1,
    "pcie_link_en_hwtcl": 1,
    "pipemode_sim_hwtcl": [1, "pipemode_sim"],
    "total_pcie_intf_hwtcl": 1,
    "top_topology_hwtcl": "Gen4 1x16",
    "core16_pf0_pcie_cap_port_num_hwtcl": 1,
    # Configuration extension bus
    "core16_ceb_en_hwtcl": [0, "ceb_enable"],
    "core16_ceb_pf_std_cap_last_ptr_hwtcl": [0, "ceb_pf_std_next_dw"],
    "core16_ceb_pf_ext_cap_last_ptr_hwtcl": [0, "ceb_pf_ext_next_dw"],
    "core16_ceb_vf_std_cap_last_ptr_hwtcl": [0, "ceb_vf_std_next_dw"],
    "core16_ceb_vf_ext_cap_last_ptr_hwtcl": [0, "ceb_vf_ext_next_dw"],
}

#
# values in func_params are either a single object or a list.
# When a list, element 0 is the default value of the parameter.
# Element 1 is the name of the field in the .ofss file that can be
# set to override the default.
#
# When element 1 begins with "AUTO_" the parameter should not be
# set in an .ofss file. Instead, it is derived from other state
# by the gen_ofs_settings script.
#
func_params = {
    "core16_{func_num}_sriov_vf_bar0_type_hwtcl": "Disabled",
    "core16_{func_num}_bar0_type_user_hwtcl": "64-bit prefetchable memory",
    "core16_{func_num}_bar0_address_width_user_hwtcl": [12, "bar0_address_width"],
    "core16_virtual_{func_num}_msix_enable_user_hwtcl": 1,
    "core16_virtual_{func_num}_exvf_msix_cap_enable_hwtcl": 0,
    "core16_virtual_{func_num}_acs_cap_enable_hwtcl": 1,
    "core16_exvf_msix_tablesize_{func_num}": 0,
    "core16_exvf_msixtable_offset_{func_num}": 0,
    "core16_exvf_msixtable_bir_{func_num}": 0,
    "core16_exvf_msixpba_offset_{func_num}": 0,
    "core16_exvf_msixpba_bir_{func_num}": 0,
    "core16_{func_num}_bar4_type_user_hwtcl": "64-bit prefetchable memory",
    "core16_{func_num}_bar4_address_width_user_hwtcl": [14, "bar4_address_width"],
    "core16_{func_num}_sriov_vf_bar0_address_width_hwtcl": 0,
    "core16_{func_num}_sriov_vf_bar4_address_width_hwtcl": 0,
    "core16_{func_num}_pci_msix_table_size_hwtcl": 6,
    "core16_{func_num}_pci_msix_table_offset_hwtcl": 1536,
    "core16_{func_num}_pci_msix_bir_hwtcl": 4,
    "core16_{func_num}_pci_msix_pba_offset_hwtcl": 1550,
    "core16_{func_num}_pci_msix_pba_hwtcl": 4,
    "core16_{func_num}_pci_msix_table_size_vfcomm_cs2_hwtcl": 4,
    # PCIe address translation (PASID, ATS and PRS capabilities)
    "core16_virtual_{func_num}_ats_cap_enable_hwtcl": [0, "ats_cap_enable"],
    "core16_{func_num}_vf_ats_cap_enable_hwtcl": [0, "vf_ats_cap_enable"],
    "core16_virtual_{func_num}_prs_ext_cap_enable_hwtcl": [0, "prs_ext_cap_enable"],
    "core16_virtual_{func_num}_pasid_cap_enable_hwtcl": [0, "pasid_cap_enable"],
    # The "AUTO" prefix is a hint to the script that this parameter is not
    # intended to be configurable in the .ofss file. Instead, it is a function
    # of other parameters. In this case, of pasid_cap_enable.
    "core16_{func_num}_pasid_cap_max_pasid_width": [
        0,
        "AUTO_pasid_cap_max_pasid_width",
    ],
    "core16_{func_num}_pci_type0_vendor_id_hwtcl": ["0x00008086", "pci_type0_vendor_id"],
    "core16_{func_num}_pci_type0_device_id_hwtcl": ["0x0000bcce", "pci_type0_device_id"], 
    "core16_{func_num}_revision_id_hwtcl": ["0x00000001", "revision_id"],
    "core16_{func_num}_class_code_hwtcl": ["0x00120000", "class_code"],
    "core16_{func_num}_subsys_vendor_id_hwtcl": ["0x00008086", "subsys_vendor_id"],
    "core16_{func_num}_subsys_dev_id_hwtcl": ["0x00001771", "subsys_dev_id"]
}

multi_vfs_func_params = {
    "core16_exvf_subsysid_{func_num}": ["0x00001771", "exvf_subsysid"],
    "core16_{func_num}_sriov_vf_device_id": ["0x0000bccf", "sriov_vf_device_id"],
    "core16_{func_num}_vf_acs_cap_enable_hwtcl": 1,
    "core16_virtual_{func_num}_exvf_msix_cap_enable_hwtcl": 1,
    "core16_exvf_msixpba_bir_{func_num}": 4,
    "core16_{func_num}_sriov_vf_bar0_type_hwtcl": "64-bit prefetchable memory",
    "core16_{func_num}_sriov_vf_bar0_address_width_hwtcl": [
        12,
        "vf_bar0_address_width",
    ],
    "core16_{func_num}_sriov_vf_bar4_type_hwtcl": "64-bit prefetchable memory",
    "core16_{func_num}_sriov_vf_bar4_address_width_hwtcl": [
        14,
        "vf_bar4_address_width",
    ],
    "core16_exvf_msix_tablesize_{func_num}": 6,
    "core16_exvf_msixtable_offset_{func_num}": 1536,
    "core16_exvf_msixtable_bir_{func_num}": 4,
    "core16_exvf_msixpba_offset_{func_num}": 1550,
    "core16_exvf_msixpba_bir_{func_num}": 4,
}

def set_top_topology(part, pcie_gen, pcie_instances, pcie_lanes):
    """
    The PCIe specification for native Agilex 5 is messy, with the user forced
    to match the width to generation and lanes. Given a requested topology,
    pick a bus width and generate the configuration string.

    Agilex 5 speed grade 6 supports only Gen3.
    """
    pcie_gen = int(pcie_gen)
    pcie_lanes = int(pcie_lanes)
    # Check the parts speed
    try:
        r = subprocess.run(["quartus_sh", "--tcl_eval", "get_part_info",
                             "-speed_grade", part], stdout=subprocess.PIPE)
    except:
        print(f"ERROR requesting speed grade from quartus_sh for {part}")
        sys.exit(1)

    speed = int(r.stdout.decode('utf-8').strip())
    if speed >= 6 and pcie_gen > 3:
        print(f"\n *** Reducing PCIe to Gen3 to match Agilex 5 speed grade {speed} ***")
        pcie_gen = 3

    # Most configurations are 128 bits wide
    width = 128
    if pcie_gen >= 4:
        if pcie_lanes >= 8:
            width = 512
        elif pcie_lanes == 4:
            width = 256

    return f"Gen{pcie_gen} x{pcie_lanes} Interface {width} bit"
