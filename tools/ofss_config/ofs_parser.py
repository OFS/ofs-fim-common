#!/usr/bin/env python

# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

import argparse
import collections
import configparser
import logging
import logging.handlers
import os
import sys


def print_ip_config(configuration):
    """
    Output all OFSS configurations
    """
    for section, section_values in configuration.items():
        logging.info(f"\t{section}:")
        for param, value in section_values.items():
            logging.info(f"\t\t{param} : {value}")


def process_input_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--ofss",
        "--ini",
        dest="ofss",
        nargs="+",
        required=True,
        help="Input OFSS config file",
    )

    return parser.parse_args()


def process_config_sections(ofss_config):
    """
    Parse each section of OFSS file for IP pertinent info
    """
    curr_ip_config = {}
    for section in ofss_config:
        if section not in ["DEFAULT", "ip", "include"]:
            curr_ip_config[section] = dict(ofss_config.items(section))

    return curr_ip_config


def process_config_includes(ofss_config_files_queue, ofss_config):
    """
    Gather all subsequent OFSS files to be processed
    """
    if "include" in ofss_config:
        for elem in ofss_config["include"]:
            ofss_config_files_queue.append(os.path.expandvars(elem).replace('"', ""))


def check_ofs_config(ofs_config):
    """
    Check that all pertinent info for the design is provided. 
    These parameters are necessary for subsequent actions executed by OFSS Config tool
    """
    required_info = ["platform", "family", "part", "device_id"]
    for elem in required_info:
        if elem not in ofs_config.keys():
            logging.info(f"{elem} not found for currenty OFS configuration")
            sys.exit(1)

    if ofs_config["family"].lower() != "agilex":
        logging.info(f"OFSS Config tool currently only supporting Agilex")
        sys.exit(1)


def check_num_ip_configs(ip, ip_config):
    """
    Check there isn't more than 1 configuration setting for each IP.
    PCIe is the only exception since there can be PCIe settings for Host and SoC
    """
    if ip == "pcie":
        return 

    if len(ip_config) > 1:
        logging.info(f"!!Error!! {ip} should only have 1 set of configuration")
        logging.info("Seeing the following desired configs")
        for ip_c in ip_config:
            logging.info(f"{ip_c}")
        sys.exit(1)

def check_configurations(ofs_ip_configurations):
    """
    Check that overall OFS setting is provided
    """
    if "ofs" not in ofs_ip_configurations:
        logging.info("!!Error!! Must have OFS project info")
        sys.exit(1)

    check_ofs_config(ofs_ip_configurations["ofs"][0]["settings"])

def process_ofss_configs(ofss_list):
    """
    Breadth First Search for including and parsing all OFSS files.
    OFSS files can be passed in as individual files on the cmd line, or
    as files under the 'include' section.
    All OFSS configurations are stored in one dictionary structure
    """
    ofss_config_files_queue = collections.deque()

    for ofss_string in ofss_list:
        ofss_elems = ofss_string.split(",")
        for ofss in ofss_elems:
            if ofss:
                ofss_abs_path = os.path.abspath(ofss)
                ofss_config_files_queue.append(ofss_abs_path)

    ofs_ip_configurations = collections.defaultdict(list)
    already_processed_configs = set()
    while ofss_config_files_queue:
        curr_config = configparser.ConfigParser(allow_no_value=True)
        curr_config.optionxform = str

        curr_ofss_file = ofss_config_files_queue.popleft()

        if not os.path.exists(curr_ofss_file):
            raise FileNotFoundError(f"{curr_ofss_file} not found")

        if curr_ofss_file in already_processed_configs:
            continue

        ip_type = None
        curr_config.read(curr_ofss_file)
        if "ip" in curr_config:
            ip_type = curr_config["ip"]["type"].lower()

        process_config_includes(ofss_config_files_queue, curr_config)
        if ip_type is not None:
            ofs_ip_configurations[ip_type].append(process_config_sections(curr_config))
            check_num_ip_configs(ip_type, ofs_ip_configurations[ip_type])

        already_processed_configs.add(curr_ofss_file)

    check_configurations(ofs_ip_configurations)

    return ofs_ip_configurations


def main():
    args = process_input_arguments()
    ofs_ip_configurations = process_ofss_configs(args.ofss)

    for ip, ip_configurations in ofs_ip_configurations.items():
        for ip_config in ip_configurations:
            print_ip_config(ip_config)


if __name__ == "__main__":
    main()
