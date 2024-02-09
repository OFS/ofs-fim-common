#!/usr/bin/env python

# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

import logging
import logging.handlers
import os

from ofs_ip import OFS


ETH_F_RSFEC = {
    'IEEE_802.3_BASE-R_Firecode': 1,
    'IEEE_802.3_RS_528_514': 2, 
    'IEEE_802.3_RS_544_514': 3
}

ETH_F_CLIENT = {
    'MAC Segmented': 0,
    'MAC Avalon ST': 1
}

class HSSI(OFS):
    """
    Class used for configuring HSSI. Inherits from OFS class 
    Contains logic for generating IP files for HSSI
    """
    def __init__(self, ofs_config, hssi_config, target):
        super().__init__(ofs_config, target)
        self.ip_type = "HSSI"
        self.hssi_config = hssi_config
        self.ip_component = "hssi_ss"
        self.ip_path = os.path.join(
            self.target_rootdir, "ipss", "hssi", "qip", "hssi_ss"
        )

        self.num_channels = 0
        self.start_channel = 0
        self.data_rate = ""
        self.ports = None
        self.eth_f_rsfec = None
        self.client_interface = None

        self.HSSI_PARAM = None

    def get_quartus_search_string(self):
        return "$OFS_ROOTDIR/ipss/hssi/qip/hssi_ss/presets,$"

    def check_configuration(self):
        """
        Ensure configuration is valid. Refer to README or design specs for more info
        Abort if violation
        """
        upper_bound = {
            "10GbE": 16,
            "25GbE": 8,
            "100GAUI-2": 4,
            "100GCAUI-4": 4,
            "200GAUI-4": 2,
            "400GAUI-8": 1,
        }
        if self.data_rate not in upper_bound.keys():
            self._errorExit(
                f"!!HSSI Config Error!! Data_rate {self.data_rate} currently not supported for this OFS Release's OFS Configuration Tool"
            )
        else:
            max_channels = upper_bound[self.data_rate]
            if self.num_channels > max_channels:
                self._errorExit(
                    f"!!HSSI Config Error!! With data rate {self.data_rate}, cannot exceed {max_channels} channels"
                )

    def get_ip_settings(self):
        """
        Get IP settings from configuration dictionary
        """
        self.ip_output_name = self.hssi_config["settings"]["output_name"]
        self.ip_output_base = f"{self.ip_path}/{self.ip_output_name}"
        self.ip_file = f"{self.ip_output_base}.ip"
        self.artifacts_to_clean.append(self.ip_file)
        self.artifacts_to_clean.append(self.ip_output_base)

        self.num_channels = int(self.hssi_config["settings"]["num_channels"])
        self.start_channel = int(self.hssi_config["settings"].get("start_channel", 0))

        self.data_rate = self.hssi_config["settings"]["data_rate"]
        self.eth_f_rsfec = self.hssi_config["settings"].get("eth_f_rsfec", None)
        self.client_interface = self.hssi_config["settings"].get("client_interface", None)
        if "preset" in self.hssi_config["settings"]:
            self.ip_preset = self.hssi_config["settings"]["preset"]
        else:
            self.set_default_params()

    def process_configuration(self):
        """
        Check and set up logic for IP component param configuration
        """
        self.get_ip_settings()
        self.check_configuration()

        incrementer = 1
        if self.data_rate in ["100GCAUI-4", "100GAUI-2", "200GAUI-4"]:
            incrementer = 4

        self.ports = [self.start_channel + (incrementer * i) for i in range(self.num_channels)]

        if not self.ip_preset:
            self.set_component_params()

    def set_default_params(self):
        """
        Set the minimum IP default parameters
        """
        for port in range(20):
            self.ip_component_params[f"PORT{port}_ENABLED_GUI"] = 0
            self.ip_component_params[f"p{port}_eth_f_ENABLE_AN"] = 0
            self.ip_component_params[f"p{port}_eth_f_ENABLE_LT"] = 0
            self.ip_component_params[f"PORT{port}_PROFILE_GUI"] = "25GbE"
            self.ip_component_params[f"p{port}_eth_f_PTP_LOGIC_RES_OPT_GUI"] = 3
            self.ip_component_params[f"p{port}_ehip_PO_CAL_ENABLE"] = 0
            self.ip_component_params[f"p{port}_eth_f_txmac_saddr_gui"] = 73588229205
            self.ip_component_params[f"PORT{port}_NUM_OF_STREAM"] = 2
            self.ip_component_params[f"p{port}_ehip_HOTPLUG_EN"] = 1
            
            

    def set_component_params(self):
        """
        Update IP component parameters
        """
        enabled_rsfec = 0 if self.data_rate == "10GbE" else 1

        for port_num in self.ports:
            self.ip_component_params[f"PORT{port_num}_PROFILE_GUI"] = self.data_rate
            self.ip_component_params[f"PORT{port_num}_ENABLED_GUI"] = "1"
            self.ip_component_params[f"PORT{port_num}_RSFEC_GUI"] = enabled_rsfec
            if self.client_interface is not None:
                self.ip_component_params[f"p{port_num}_eth_f_CLIENT_INT_GUI"] = ETH_F_CLIENT[self.client_interface]
            if self.eth_f_rsfec is not None:
                self.ip_component_params[f"p{port_num}_eth_f_RSFEC_TYPE_P0_GUI"] = ETH_F_RSFEC[self.eth_f_rsfec]
        self.ip_component_params["NUM_ENABLED_PORTS"] = self.num_channels


    def summarize_configuration(self):
        """
        HSSI Configuration Summary
        """
        logging.info("")
        logging.info("=========================")
        logging.info("HSSI Summary")
        logging.info("=========================")
        logging.info(f"HSSI IP Path: {self.ip_path}")
        logging.info(f"Num Channels:{self.num_channels}")
        logging.info(f"Start Channel:{self.start_channel}")
        logging.info(f"Data Rate:{self.data_rate}")
        logging.info("Configuring the following ports:")
        for port_num in self.ports:
            logging.info(f"Port{port_num}")
        logging.info("")
