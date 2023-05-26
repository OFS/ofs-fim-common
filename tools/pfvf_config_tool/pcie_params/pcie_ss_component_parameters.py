# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: MIT

header_info = {
    "Family": "Agilex", 
    "Part": "AGFB014R24A2E2V",
    "IpDeployFile": "pcie_ss.sh",
    "IpFile": "pcie_ss.ip",
    "OutputName": "pcie_ss", 
    "ComponentName": "pcie_ss"
}

component_params = {
        "axi_lite_clk_freq_user_hwtcl": 100,
        "core16_total_pf_count_hwtcl": 5,
        "core16_enable_multi_func_hwtcl": 1,
        "core16_ctrl_shadow_en_hwtcl": 1, 
        "core16_comp_timeout_en_hwtcl": 1,
        "core16_enable_10bit_tag_support_intf_hwtcl": 1,
        "core16_msix_en_table_hwtcl" : 1,
        "core16_msix_table_size_hwtcl" : 7,
        "core16_msix_bir_hwtcl" : 4,
        "core16_msix_bar_offset_hwtcl" : 12288,
        "core16_msix_vector_alloc_hwtcl" : "Static"
}

func_params = {
            "core16_{func_num}_expansion_base_address_register_hwtcl": "Disabled",
            "core16_{func_num}_sriov_vf_bar0_type_hwtcl": "64-bit prefetchable memory",
            "core16_{func_num}_bar0_type_user_hwtcl": "64-bit prefetchable memory",
            "core16_{func_num}_bar0_address_width_user_hwtcl": 12,
            "core16_virtual_{func_num}_msix_enable_user_hwtcl": 1,
            "core16_virtual_{func_num}_exvf_msix_cap_enable_hwtcl": 0,
            "core16_{func_num}_vf_acs_cap_enable_hwtcl": 1,
            "core16_exvf_msix_tablesize_{func_num}": 0, 
            "core16_exvf_msixtable_offset_{func_num}": 0,
            "core16_exvf_msixtable_bir_{func_num}": 0,
            "core16_exvf_msixpba_offset_{func_num}": 0,
            "core16_exvf_msixpba_bir_{func_num}": 0,
            "core16_{func_num}_pci_type0_device_id_hwtcl": 48334,
            "core16_{func_num}_sriov_vf_device_id": 48335,
            "core16_{func_num}_bar4_type_user_hwtcl": "64-bit prefetchable memory",
            "core16_{func_num}_bar4_address_width_user_hwtcl": 14,
            "core16_{func_num}_sriov_vf_bar0_address_width_hwtcl": 0,
            "core16_{func_num}_sriov_vf_bar4_type_hwtcl": "Disabled", 
            "core16_{func_num}_sriov_vf_bar4_address_width_hwtcl": 0,
            "core16_{func_num}_pci_msix_table_size_hwtcl": 6,
            "core16_{func_num}_pci_msix_table_offset_hwtcl": 1536, 
            "core16_{func_num}_pci_msix_bir_hwtcl": 4, 
            "core16_{func_num}_pci_msix_pba_offset_hwtcl": 1550, 
            "core16_{func_num}_pci_msix_pba_hwtcl": 4
}

multi_vfs_func_params = {
            "core16_virtual_{func_num}_msix_enable_user_hwtcl": 1,
            "core16_virtual_{func_num}_exvf_msix_cap_enable_hwtcl": 1,
            "core16_exvf_msixpba_bir_{func_num}": 4,
            "core16_{func_num}_sriov_vf_bar0_address_width_hwtcl": 12,
            "core16_{func_num}_sriov_vf_bar4_type_hwtcl": "64-bit prefetchable memory",
            "core16_{func_num}_sriov_vf_bar4_address_width_hwtcl": 14,
            "core16_{func_num}_pci_msix_table_size_hwtcl": 6,
            "core16_{func_num}_pci_msix_table_offset_hwtcl": 1536,
            "core16_{func_num}_pci_msix_bir_hwtcl": 4,
            "core16_{func_num}_pci_msix_pba_offset_hwtcl": 1550,
            "core16_{func_num}_pci_msix_pba_hwtcl": 4,
}
