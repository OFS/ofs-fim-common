#!/usr/bin/env python

# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

import argparse
import logging
import logging.handlers
import sys

from hssi_ip import HSSI as HSSI
from iopll_ip import IOPLL as IOPLL
from memory_ip import Memory as Memory, SimMemory as SimMemory
import ofs_parser
from pcie_ip import PCIe as PCIe


def configure_logging():
    """
    Set up logging module's options for writing to stdout and to a designated log file
    """
    logger = logging.getLogger(__name__)
    msg_format = "%(message)s"
    formatter = logging.Formatter(msg_format)
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)

    stdout_handler = logging.StreamHandler(sys.stdout)
    stdout_handler.setLevel(logging.INFO)
    stdout_handler.setFormatter(formatter)
    logger.addHandler(stdout_handler)

    # file_handler = logging.handlers.RotatingFileHandler('debug.log', mode='w')
    # file_handler.setLevel(logging.DEBUG)
    # file_handler.setFormatter(formatter)
    # logger.addHandler(file_handler)


def process_input_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--ofss",
        "--ini",
        dest="ofss",
        nargs="+",
        type=str,
        required=True,
        help="Input OFSS config file",
    )
    parser.add_argument(
        "--target",
        help="""Destination root directory (a work directory or OFS_ROOTDIR).
                                Defaults to $OFS_ROOTDIR.""",
    )
    parser.add_argument(
        "--platform", default="n6001", help="Platform tool is running for"
    )
    parser.add_argument("--debug", action="store_true", help="Dumps IP Deploy Commands into 'ip_deploy_cmds.log' file")

    return parser.parse_args()


def instantiate_ips(ofs_ip_configurations, target_dir):
    """
    For each IP that has to be configured, instantiate the corresponding IP class
    """
    ip_type = ["iopll", "pcie", "memory", "hssi"]
    to_config = []
    ofs_config = ofs_ip_configurations["ofs"][0]

    # If IOPLL's p_clk is to be configured, this should made visible to other IPs.
    # This is made possible by updating the ofs_config dictionary's overall project settings.
    if "iopll" in ofs_ip_configurations:
        ofs_config["settings"]["p_clk"] = ofs_ip_configurations["iopll"][0]["p_clk"][
            "freq"
        ]

    for ip in ip_type:
        for ip_instance in ofs_ip_configurations[ip]:
            if ip == "iopll":
                to_config.append(IOPLL(ofs_config, ip_instance, target_dir))
            elif ip == "pcie":
                to_config.append(PCIe(ofs_config, ip_instance, target_dir))
            elif ip == "memory":
                to_config.append(Memory(ofs_config, ip_instance, target_dir))
                to_config.append(SimMemory(ofs_config, ip_instance, target_dir))
            elif ip == "hssi":
                to_config.append(HSSI(ofs_config, ip_instance, target_dir))

    return to_config


def main():
    # Setup Procedures
    configure_logging()
    args = process_input_arguments()

    if args.debug:
        with open("ip_deploy_cmds.log", "w") as fOut:
            pass

    ofs_ip_configurations = ofs_parser.process_ofss_configs(args.ofss)
    ips_to_config = instantiate_ips(ofs_ip_configurations, args.target)

    for ip, ip_configurations in ofs_ip_configurations.items():
        logging.info(f"{ip}")
        for ip_config in ip_configurations:
            ofs_parser.print_ip_config(ip_config)

    logging.info("=============================================")
    logging.info("Beginning OFS IP Configuration Tool")
    logging.info("=============================================")

    updated_ip_files = []
    for ip in ips_to_config:
        ip.process_configuration()
        ip.summarize_configuration()
        ip.deploy()
        if args.debug:
            ip.dump_ip_deploy_cmd()
        updated_ip_files.append(f"{ip.ip_file}")

    logging.info("=============================================")
    logging.info("OFS IP Configuration Tool Complete for:")
    logging.info(f"{args.ofss}")
    logging.info("Updated the following:")
    for ip_file in updated_ip_files:
        logging.info(f"\t - {ip_file}")
    logging.info("=============================================")


if __name__ == "__main__":
    main()
