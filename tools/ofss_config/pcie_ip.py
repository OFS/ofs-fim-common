#!/usr/bin/env python

# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

import re
import os
import logging
import logging.handlers
from importlib.machinery import SourceFileLoader

from ofs_ip import OFS


class PCIe(OFS):
    """
    Class used for configuring PCIe. Inherits from OFS class 
    Contains logic for generating IP file for PCIe
    """
    def __init__(self, ofs_config, pcie_config, target):
        super().__init__(ofs_config, target)
        self.ip_type = "PCIe"
        self.pcie_config = pcie_config
        self.ip_component = pcie_config["settings"].get("ip_component", "pcie_ss")
        self.ip_path = os.path.join(self.target_rootdir, "ipss", "pcie", "qip")

        self.pf_vf_count = {}
        self.num_pfs = 0
        self.num_vfs = 0
        self.all_pfs = None

        self.pcie_gen, self.pcie_instances = None, None
        self.pcie_lane_width = None
        self.PCIE_AVAILABLE_LANES = 16

        self.PCIE_SS_PARAM = None
        self.set_ip_params()

    def set_ip_params(self):
        param_default_path = os.path.join(
            os.path.dirname(__file__), f"ip_params/{self.ip_component}_parameters.py"
        )
        logging.info(f"{self.ip_component} source file: {param_default_path}")

        self.PCIE_SS_PARAM = SourceFileLoader(
            f"{self.ip_component}_parameters", param_default_path
        ).load_module()

    def check_configuration(self):
        """
        Ensure configuration is valid. Refer to README or design specs for more info
        Abort if violation
        """
        # check # of PFS
        if self.num_pfs > 8 or self.num_pfs < 1:
            self._errorExit(
                "!!PCIe Config Error!! Number of PFS in configuration should be between 1 and 8"
            )

        # check on consecutive pfs numbering
        for pf_cnt in range(self.num_pfs):
            if f"pf{pf_cnt}" not in self.pf_vf_count:
                self._errorExit(
                    f"!!PCIe Config Error!! Configuration file must contain incremental PFs with no skipped PF. Missing  PF{pf_cnt}"
                )
        if self.platform == "n6001":
            if (
                "num_vfs" not in self.pcie_config["pf0"]
                or int(self.pcie_config["pf0"]["num_vfs"]) == 0
            ):
                if "pf1" not in self.pcie_config: 
                    self._errorExit(
                        f"!!PCIe Config Error!! Need to have minimum 1 VF on PF0 or PF0 and PF1 on {self.ip_output_name}"
                    )

        if self.platform == "f2000x" and self.ip_output_name == "soc_pcie_ss":
            if (
                "num_vfs" not in self.pcie_config["pf0"]
                or int(self.pcie_config["pf0"]["num_vfs"]) == 0
            ):
                self._errorExit(
                    f"!!PCIe Config Error!! Need to have minimum 1 VF on PF0 on {self.ip_output_name}"
                )

        if self.pcie_gen is not None:
            if self.pcie_gen not in ["4", "5"]:
                self._errorExit(
                    f"!!PCIe Config Error!! Currently only supporting PCIe Gen 4 or 5"
                )
            if self.pcie_instances is None:
                self._errorExit(
                    f"!!PCIe Config Error!! Must provide number of PCIe instances"
                )
             

    def get_ip_settings(self):
        """
        Get IP settings from configuration dictionary
        """
        self.ip_output_name = self.pcie_config["settings"]["output_name"]
        self.ip_output_base = f"{self.ip_path}/{self.ip_output_name}"
        self.ip_file = f"{self.ip_output_base}.ip"
        self.artifacts_to_clean.append(self.ip_file)
        self.artifacts_to_clean.append(self.ip_output_base)

        # Try to pick a reasonable default. This should be driven by the
        # available HW.
        self.pcie_lane_width = int(self.PCIE_AVAILABLE_LANES)

        if "pcie_gen" in self.pcie_config["settings"]:
            self.pcie_gen  = self.pcie_config["settings"]["pcie_gen"]

        if "pcie_instances" in self.pcie_config["settings"]:
            self.pcie_instances = self.pcie_config["settings"]["pcie_instances"]
            self.pcie_lane_width = int(self.PCIE_AVAILABLE_LANES / int(self.pcie_instances))
 
        if "pcie_lane_width" in self.pcie_config["settings"]:
            self.pcie_lane_width = self.pcie_config["settings"]["pcie_lane_width"]

        if "preset" in self.pcie_config["settings"]:
            self.ip_preset = self.pcie_config["settings"]["preset"]
            print(f"{self.ip_preset}")
        else:
            for (
                pcie_param,
                pcie_param_value,
            ) in self.PCIE_SS_PARAM.default_component_params.items():
                self.ip_component_params[pcie_param] = pcie_param_value
                logging.debug(f"Setting pcie config {pcie_param} to {pcie_param_value}")

    def override_pf_param_from_ofss(self, pf, param):
        """Update individual parameters from values in the OFSS file. Returns None
        if the value is not specified in the OFSS file."""
        # When PASID capability is enabled on a PF, set the max PASID
        # width to 20. The PCIe standard allows the ID width to be narrower
        # but the full width is generally assumed by the host.
        if param == "AUTO_pasid_cap_max_pasid_width":
            if "pasid_cap_enable" in self.pcie_config[pf] and self._check_config_enable(
                self.pcie_config[pf]["pasid_cap_enable"]
            ):
                return 20

            return None

        return self.pcie_config[pf].get(param, None)

    def process_configuration(self):
        """
        Check and set up logic for IP component param configuration
        """
        self.get_ip_settings()
        if not self.ip_preset:
            self.all_pfs = [
                str(section) for section in self.pcie_config if section.startswith("pf")
            ]
            self.pf_vf_count = {
                str(section): 0 for section in self.pcie_config if section.startswith("pf")
            }

            self.num_pfs = len(self.all_pfs)
            self.check_configuration()

            # If IOPLL OFSS is present to configuration the 'p_clk',
            # Update PCIe's IP file's `axi_st_clk_freq_user_hwtcl` parameter
            if self.p_clk:
                self.ip_component_params["axi_st_clk_freq_user_hwtcl"] = f"{self.p_clk}MHz"

            if self.pcie_gen is not None and self.pcie_instances is not None:
                self.ip_component_params["top_topology_hwtcl"] = f"Gen{self.pcie_gen} {self.pcie_instances}x{self.pcie_lane_width}"

            for pf in self.all_pfs:
                self.process_pfs(pf)

            self.ip_component_params["core16_total_pf_count_hwtcl"] = self.num_pfs

            if self.num_vfs > 0:
                self.ip_component_params["core16_enable_sriov_hwtcl"] = 1

            # The PCIe SS stores a second link's configuration in parameters
            # beginning with "core8_". Replicate the first link's configuration.
            # OFS expects the two links to be configured identically.
            if self.pcie_instances is not None and int(self.pcie_instances) > 1:
                core16_keys = [k for k in self.ip_component_params if k[:7] == 'core16_']
                for c16_k in core16_keys:
                    c8_k = 'core8' + c16_k[6:]
                    if not c8_k in self.ip_component_params:
                        self.ip_component_params[c8_k] = self.ip_component_params[c16_k]

    def process_pfs(self, pf):
        """
        Configure PCIe's PF
        """
        self.set_func_params(self.PCIE_SS_PARAM.func_params, pf)
        self.process_vfs(pf)

        self.ip_component_params[f"core16_{pf}_vf_count_hwtcl"] = self.pf_vf_count[pf]

    def process_vfs(self, pf):
        """
        Configure VFs for a particular PF
        """
        num_vfs_in_curr_pf = (
            int(self.pcie_config[pf]["num_vfs"])
            if "num_vfs" in self.pcie_config[pf]
            else 0
        )
        self.num_vfs += num_vfs_in_curr_pf
        if self.num_vfs > 2000:
            self._errorExit(
                f"!!PCIe Config Error!! Number of VFs should not exceed 2000 across all PFs"
            )
        self.pf_vf_count[pf] = num_vfs_in_curr_pf

        if num_vfs_in_curr_pf > 0:
            self.set_func_params(self.PCIE_SS_PARAM.multi_vfs_func_params, pf)

    def set_func_params(self, param_dict, pf):
        """
        Update IP component parameters
        """
        for param, default_value in param_dict.items():
            pf_param = f"{param.format(func_num=pf)}"
            # "value" will either be a list or single object. When it is a list,
            # element 0 is the default value of the parameter. Element 1 is the
            # name of the field in the .ofss file that can be set to override
            # the default.
            param_value = default_value
            if isinstance(default_value, list):
                param_value, ofss_param = default_value
                override = self.override_pf_param_from_ofss(pf, ofss_param)
                if override:
                    param_value = override

            self.ip_component_params[pf_param] = param_value

    def summarize_configuration(self):
        """
        PCIe Configuration Summary
        """
        logging.info("")
        logging.info("=========================")
        logging.info(f"PCIe ({self.ip_component}) Summary")
        logging.info("=========================")
        logging.info(f"Total PF Count = {self.num_pfs}")
        logging.info(f"Total VF Count = {self.num_vfs}")
        logging.info(f"PF VF Mapping = {self.pf_vf_count}")
        logging.info("")
