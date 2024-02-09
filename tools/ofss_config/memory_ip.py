#!/usr/bin/env python

# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

import os
import logging
import logging.handlers

from ofs_ip import OFS


class Memory(OFS):
    """
    Class used for configuring Memory. Inherits from OFS class 
    Contains logic for generating IP files for Memory
    Currently supporting configuration with presets
    """
    def __init__(self, ofs_config, memory_config, target):
        super().__init__(ofs_config, target)
        self.ip_type = "Memory"
        self.memory_config = memory_config
        self.ip_component = "mem_ss"
        self.ip_instance_name = "mem_ss"
        self.ip_path = os.path.join(self.target_rootdir, "ipss", "mem", "qip", "mem_ss")

    def check_configuration(self):
        """
        Ensure configuration is valid. Refer to README or design specs for more info
        Abort if violation
        """
        if self.ip_preset not in ["n6001", "f2000x", "fseries-dk"]:
            self._errorExit(
                f'!!Memory Config Error!! Currently only supporting "--preset" values of "n6001", "f2000x", or "fseries-dk"'
            )

    def get_ip_settings(self):
        """
        Get IP settings from configuration dictionary
        """
        self.ip_output_name = self.memory_config["settings"]["output_name"]
        self.ip_output_base = f"{self.ip_path}/{self.ip_output_name}"
        self.ip_file = f"{self.ip_output_base}.ip"
        self.artifacts_to_clean.append(self.ip_file)
        self.artifacts_to_clean.append(self.ip_output_base)

        self.ip_preset = self.memory_config["settings"]["preset"]

    def process_configuration(self):
        """
        Check and set up logic for IP component param configuration
        """
        self.get_ip_settings()
        #self.check_configuration()

    def summarize_configuration(self):
        """
        Memory Configuration Summary
        """
        logging.info("")
        logging.info("=========================")
        logging.info("Memory Summary")
        logging.info("=========================")
        logging.info(f"Preset = {self.ip_preset}")
        logging.info("")


class SimMemory(OFS):
    """
    Class used for configuring Memory. Inherits from OFS class 
    Contains logic for generating IP file for SimMemory
    Currently supporting configuration with presets
    """
    def __init__(self, ofs_config, memory_config, target):
        super().__init__(ofs_config, target)
        self.ip_type = "SimMemory"
        self.memory_config = memory_config
        self.ip_component = "altera_emif_mem_model"
        self.ip_path = os.path.join(self.target_rootdir, "ipss", "mem", "qip", "ed_sim")

    def check_configuration(self):
        """
        Ensure configuration is valid. Refer to README or design specs for more info
        Abort if violation
        """
        if self.ip_preset not in ["n6001", "f2000x", "fseries-dk"]:
            self._errorExit(
                f'!!Memory Config Error!! Currently only supporting "--preset" values of "n6001", "f2000x", or "fseries-dk"'
            )

    def get_ip_settings(self):
        """
        Get IP settings from configuration dictionary
        """
        self.ip_output_name = "ed_sim_mem"
        self.ip_output_base = f"{self.ip_path}/{self.ip_output_name}"
        self.ip_file = f"{self.ip_output_base}.ip"
        self.artifacts_to_clean.append(self.ip_file)
        self.artifacts_to_clean.append(self.ip_output_base)

        self.ip_preset = self.memory_config["settings"]["preset"]

    def process_configuration(self):
        """
        Check and set up logic for IP component param configuration
        """
        self.get_ip_settings()
        #self.check_configuration()

    def summarize_configuration(self):
        """
        SimMemory Configuration Summary
        """
        logging.info("")
        logging.info("=========================")
        logging.info("SimMemory Summary")
        logging.info("=========================")
        logging.info(f"Preset = {self.ip_preset}")
        logging.info("")
