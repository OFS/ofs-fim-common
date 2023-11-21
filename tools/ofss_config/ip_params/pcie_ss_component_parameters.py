# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: MIT

default_component_params = {
    "g3_pld_clkfreq_user_hwtcl": "250MHz",
    "g4_pld_clkfreq_user_hwtcl": "500MHz",
    "axi_st_clk_freq_user_hwtcl": "400MHz",
    "axi_lite_clk_freq_user_hwtcl": 100,
    "core16_dwdn_msg_fwd_en_hwtcl" : 1,
    "core16_flr_req_drop_en_hwtcl" : 0,
    "core16_enable_multi_func_hwtcl": 1,
    "core16_enable_sriov_hwtcl": "1",
    "core16_enable_10bit_tag_support_intf_hwtcl": 1,
    "core16_cpl_reordering_en_hwtcl": "1",
    "core16_ctrl_shadow_en_hwtcl": 1,
    "core16_comp_timeout_en_hwtcl": 1,
    "pcie_link_en_hwtcl": "1",
    "total_pcie_intf_hwtcl": "1",
    "pcie_ss_func_mode_hwtcl": "AXI-ST Data Mover",
    "top_topology_hwtcl": "Gen4 1x16",
    "core8_virtual_pf0_msix_enable_user_hwtcl": "0",
    "core8_pf0_pci_msix_table_size_hwtcl": "0",
    "core16_pf0_gen3_eq_pset_req_vec_hwtcl": "0x00000004",
    "core16_pf0_pcie_cap_port_num_hwtcl": "1",
    "core16_msix_en_table_hwtcl": 1,
    "core16_msix_table_size_hwtcl": 7,
    "core16_msix_bir_hwtcl": 4,
    "core16_msix_bar_offset_hwtcl": 12288,
    "core16_msix_vector_alloc_hwtcl": "Static",
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
    "core16_{func_num}_expansion_base_address_register_hwtcl": "Disabled",
    "core16_{func_num}_sriov_vf_bar0_type_hwtcl": "64-bit prefetchable memory",
    "core16_{func_num}_sriov_vf_bar0_type_user_hwtcl": "64-bit prefetchable memory",
    "core16_{func_num}_bar0_type_user_hwtcl": "64-bit prefetchable memory",
    "core16_{func_num}_bar0_address_width_user_hwtcl": [12, "bar0_address_width"],
    "core16_virtual_{func_num}_msix_enable_user_hwtcl": 1,
    "core16_virtual_{func_num}_exvf_msix_cap_enable_hwtcl": 0,
    "core16_virtual_{func_num}_acs_cap_enable_hwtcl": 1,
    "core16_{func_num}_vf_acs_cap_enable_hwtcl": 1,
    "core16_exvf_msix_tablesize_{func_num}": 0,
    "core16_exvf_msixtable_offset_{func_num}": 0,
    "core16_exvf_msixtable_bir_{func_num}": 0,
    "core16_exvf_msixpba_offset_{func_num}": 0,
    "core16_exvf_msixpba_bir_{func_num}": 0,
    "core16_{func_num}_bar4_type_user_hwtcl": "64-bit prefetchable memory",
    "core16_{func_num}_bar4_address_width_user_hwtcl": [14, "bar4_address_width"],
    "core16_{func_num}_sriov_vf_bar0_address_width_hwtcl": 0,
    "core16_{func_num}_sriov_vf_bar4_type_hwtcl": "Disabled",
    "core16_{func_num}_sriov_vf_bar4_type_user_hwtcl": "Disabled",
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
    "core16_{func_num}_pci_type0_vendor_id_user_hwtcl": ["0x00008086", "pci_type0_vendor_id"],
    "core16_{func_num}_pci_type0_device_id_hwtcl": ["0x0000bcce", "pci_type0_device_id"], 
    "core16_{func_num}_revision_id_hwtcl": ["0x00000001", "revision_id"],
    "core16_{func_num}_revision_id_user_hwtcl": ["0x00000001", "revision_id"],
    "core16_{func_num}_class_code_hwtcl": ["0x00120000", "class_code"],
    "core16_{func_num}_subsys_vendor_id_hwtcl": ["0x00008086", "subsys_vendor_id"],
    "core16_{func_num}_subsys_dev_id_hwtcl": ["0x00001771", "subsys_dev_id"],
    "core16_{func_num}_sriov_vf_device_id": ["0x0000bccf", "sriov_vf_device_id"],
    "core16_exvf_subsysid_{func_num}": ["0x00001771", "exvf_subsysid"]
}

multi_vfs_func_params = {
    "core16_virtual_{func_num}_msix_enable_user_hwtcl": 1,
    "core16_virtual_{func_num}_exvf_msix_cap_enable_hwtcl": 1,
    "core16_exvf_msixpba_bir_{func_num}": 4,
    "core16_{func_num}_sriov_vf_bar0_address_width_hwtcl": [
        12,
        "vf_bar0_address_width",
    ],
    "core16_{func_num}_sriov_vf_bar4_type_hwtcl": "64-bit prefetchable memory",
    "core16_{func_num}_sriov_vf_bar4_type_user_hwtcl": "64-bit prefetchable memory",
    "core16_{func_num}_sriov_vf_bar4_address_width_hwtcl": 14,
    "core16_exvf_msix_tablesize_{func_num}": 6,
    "core16_exvf_msixtable_offset_{func_num}": 1536,
    "core16_exvf_msixtable_bir_{func_num}": 4,
    "core16_exvf_msixpba_bir_{func_num}": 4,
    "core16_exvf_msixpba_offset_{func_num}": 1550,
}
