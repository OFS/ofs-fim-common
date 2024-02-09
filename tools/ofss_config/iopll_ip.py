#!/usr/bin/env python

# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

import os
import logging
import logging.handlers
from importlib.machinery import SourceFileLoader

from ofs_ip import OFS


class IOPLL(OFS):
    """
    Class used for configuring IOPLL. Inherits from OFS class 
    Contains logic for generating IP file for sys_pll.
    p_clk configuration in IOPLL, will affect one parameter in PCIe IP
    """
    def __init__(self, ofs_config, iopll_config, target):
        super().__init__(ofs_config, target)
        self.ip_type = "IOPLL"
        self.iopll_config = iopll_config
        self.ip_component = "altera_iopll"
        self.ip_path = os.path.join(
            self.target_rootdir, "ofs-common", "src", "fpga_family", "agilex", "sys_pll"
        )

        self.IOPLL_PARAM = None
        self.p_clk_div_2 = None
        self.p_clk_div_4 = None

    def check_configuration(self):
        """
        Ensure configuration is valid. Refer to README or design specs for more info
        Abort if violation. The PCIe IP may define a maximum frequency, but it varies
        by device so the Fmax checking is left to the downstream IP.
        """
        if float(self.p_clk) < 250:
            self._errorExit(
                "!!IOPLL Config Error!! IOPLL p_clk should be above 250 MHz"
            )

    def get_ip_settings(self):
        """
        Get IP settings from configuration dictionary
        """
        self.ip_instance_name = self.iopll_config["settings"]["instance_name"]
        self.ip_output_name = self.iopll_config["settings"]["output_name"]
        self.ip_output_base = f"{self.ip_path}/{self.ip_output_name}"
        self.ip_file = f"{self.ip_output_base}.ip"
        self.artifacts_to_clean.append(self.ip_file)
        self.artifacts_to_clean.append(self.ip_output_base)

        iopll_default_path = os.path.join(
            os.path.dirname(__file__), "ip_params/iopll_component_parameters.py"
        )
        self.IOPLL_PARAM = SourceFileLoader(
            "iopll_component_parameters", iopll_default_path
        ).load_module()

        for iopll_param, iopll_param_value in self.IOPLL_PARAM.component_params.items():
            self.ip_component_params[iopll_param] = iopll_param_value
            logging.debug(f"Setting iopll config {iopll_param} to {iopll_param_value}")

    def process_configuration(self):
        """
        Check and set up logic for IP component param configuration
        """
        self.get_ip_settings()
        self.p_clk_div_2 = round(float(self.p_clk) / 2, 2)
        self.p_clk_div_4 = round(float(self.p_clk) / 4, 2)

        self.check_configuration()

        self.set_component_params()

    def set_component_params(self):
        """
        Update IP component parameters
        """
        self.ip_component_params["gui_output_clock_frequency0"] = self.p_clk
        self.ip_component_params["gui_output_clock_frequency2"] = self.p_clk_div_2
        self.ip_component_params["gui_output_clock_frequency5"] = self.p_clk_div_4
        self.ip_component_params["gui_output_clock_frequency_ps0"] = round(
            (1.0e6 / float(self.p_clk)), 3
        )
        self.ip_component_params["gui_output_clock_frequency_ps2"] = round(
            (1.0e6 / float(self.p_clk_div_2)), 3
        )
        self.ip_component_params["gui_output_clock_frequency_ps5"] = round(
            (1.0e6 / float(self.p_clk_div_4)), 3
        )

    def summarize_configuration(self):
        """
        IOPLL Configuration Summary
        """
        logging.info("")
        logging.info("=========================")
        logging.info("IOPLL Summary")
        logging.info("=========================")
        logging.info(f"IOPLL IP Path: {self.ip_path}")
        logging.info(f"p_clk freq = {self.p_clk}")
        logging.info(f"p_clk/2 freq = {self.p_clk_div_2}")
        logging.info(f"p_clk/4 freq = {self.p_clk_div_4}")
        logging.info("")
