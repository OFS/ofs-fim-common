#!/usr/bin/env python

# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

from glob import glob
import re
import os
import argparse
import xml.etree.ElementTree as ET
import logging
import logging.handlers
import sys
from string import Template
from importlib.machinery import SourceFileLoader


#import pcie_ss_component_parameters as PCIE_SS_PARAM
import generated_files  as GEN_FILE_PATHS

try:
    # Python 3 name
    import configparser
except ImportError:
    # Python 2 name
    import ConfigParser as configparser


def configure_logging():
    '''
    Set up logging module's options for writing to stdout and to a designated log file
    '''
    logger = logging.getLogger(__name__)  
    format = "%(message)s"
    formatter = logging.Formatter(format)
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)

    stdout_handler = logging.StreamHandler(sys.stdout)
    stdout_handler.setLevel(logging.INFO)
    stdout_handler.setFormatter(formatter)
    logger.addHandler(stdout_handler)

    #file_handler = logging.handlers.RotatingFileHandler('debug.log', mode='w')
    #file_handler.setLevel(logging.DEBUG)
    #file_handler.setFormatter(formatter)
    #logger.addHandler(file_handler)

def process_input_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ini', dest='ini', required=True, help="Input ini config file")
    parser.add_argument('--comparexml', nargs='+',
                            help='compare this projects xml with a target xml',
                            default=argparse.SUPPRESS)
    parser.add_argument('--platform', default="n6001", help="Platform tool is running for")
    
    return parser.parse_args()


class Device:
    def __init__(self):
        self.sr_region = [] # key: pf #, value: (pid, pf, vf, vf_active)
        self.pg_region = []
        self.prr_region = []
        self.pg_enabled_pfs = []
        self.pf_vf_count = {}
        self.num_pfs = 0
        self.num_vfs = 0
        self.platform = ""
        self.fpga_family = ""
        self.fim = ""
        self.part = ""
        self.output_name= ""
        self.component = ""
        self.ip_name = "pcie_ss.ip"
        self.ip_path = f'{os.environ["OFS_ROOTDIR"]}/ipss/pcie/qip'
        self.top_cfg_file = 'SampleDevice_top_cfg.sv'
        self.is_host = True
        self.PCIE_SS_PARAM = None
   
    def set_generated_output_paths(self):
        if not self.is_host:
            self.top_cfg_file = f'{os.environ["OFS_ROOTDIR"]}/src/afu_top/mux/soc_top_cfg_pkg.sv'
            self.ip_name = "soc_pcie_ss.ip"
        else: 
            self.top_cfg_file = f'{os.environ["OFS_ROOTDIR"]}/src/afu_top/mux/top_cfg_pkg.sv'
            self.ip_name = "pcie_ss.ip"

    def process_configuration(self, ini_file):
        if not ini_file:
            self.__errorExit("ini_file must be specified!")
        if not os.path.isfile(ini_file):
            self.__errorExit("File '{0}' not found!".format(ini_file))

        config = configparser.ConfigParser()
        config.read(ini_file)

        self.get_project_settings(config)
        self.set_generated_output_paths()
        self.all_pfs = [str(section)for section in config if section.startswith('pf')]
        self.pf_vf_count = {str(section):0 for section in config if section.startswith('pf')}
        self.process_pg_enabled(config)
        self.process_sr_region(config)
        self.process_pg_region(config)
        self.process_prr_region(config)

        self.num_pfs = len(self.all_pfs)

    def get_project_settings(self, config):
        self.platform = config['ProjectSettings']['platform']
        self.fim = config['ProjectSettings']['fim']
        self.fpga_family = config['ProjectSettings']['family']
        self.part = config['ProjectSettings']['part']
        self.output_name = config['ProjectSettings']['OutputName']
        self.component = config['ProjectSettings']['ComponentName']
        self.is_host = config.getboolean('ProjectSettings', 'is_host')

        pcie_default_path = f'./pcie_params/pcie_ss_component_parameters.py'
        self.PCIE_SS_PARAM = SourceFileLoader("pcie_ss_component_parameters", pcie_default_path).load_module()

    def check_pg_enable_count(self):
        if self.platform == 'n6001':
            if len(self.pg_enabled_pfs) > 1:
                raise Exception(f"{self.platform} cannot have more than 1 PG_ENABLED PF")
        elif self.platform == 'fm89' and not self.is_host:
            if len(self.pg_enabled_pfs) > 1:
                raise Exception(f"{self.platform} SOC cannot have more than 1 PG_ENABLED PF")
        elif self.platform == 'fm89' and self.is_host:
            if len(self.pg_enabled_pfs) > 0:
                raise Exception(f"{self.platform} HOST cannot have any PG_ENABLED PF")
        

    def process_pg_enabled(self, config):
        for pf_index, pf_name in enumerate(self.all_pfs):
            if config.has_option(pf_name, 'pg_enable') and config.getboolean(pf_name, 'pg_enable'):
                self.pg_enabled_pfs.append(pf_name)
        self.check_pg_enable_count()
        
    def process_sr_region(self, config):
        pid_count = 0
        # populate SR region's PFs
        for i in range(len(self.all_pfs)):
            pid_name = f'SR_PF{i}_PF{i}_PID'
            pf, vf, vf_active = i, 0, 0
            self.sr_region.append((pid_name, pf, vf, vf_active))
            pid_count += 1

        # populate SR regions' VFs
        for pf_index, pf_name in enumerate(self.all_pfs):
            num_vfs_in_curr_pf = int(config[pf_name]['num_vfs']) if config.has_option(pf_name, 'num_vfs') else 0 
            self.pf_vf_count[pf_name] = num_vfs_in_curr_pf
            self.num_vfs += num_vfs_in_curr_pf
            if pf_name in self.pg_enabled_pfs:
                continue
            for vf_index in range(num_vfs_in_curr_pf):
                pid_name = f'SR_PF{pf_index}_VF{vf_index}_PID'
                pf, vf, vf_active = pf_index, vf_index, 1
                self.sr_region.append((pid_name, pf, vf, vf_active))
    
    def process_pg_region(self, config):
        for pg_pf in self.pg_enabled_pfs:
            num_vfs_in_pf = int(config[pg_pf]['num_vfs']) if config.has_option(pg_pf, 'num_vfs') else 0 
            if num_vfs_in_pf == 0:
                return
            
            for i in range(num_vfs_in_pf):
                pid_name = f'PG_SHARED_VF_PID'
                pf_index = int(pg_pf[-1])
                pf, vf, vf_active = pf_index, i, 1
                self.pg_region.append((pid_name, pf, vf, vf_active))
        
        
    def process_prr_region(self, config):
        for pg_pf in self.pg_enabled_pfs:
            num_vfs_in_pf = int(config[pg_pf]['num_vfs']) if config.has_option(pg_pf, 'num_vfs') else 0 
            if num_vfs_in_pf == 0:
                return
            
            for i in range(num_vfs_in_pf):
                pid_name = f'PRR_{pg_pf.upper()}_VF{i}_PID'
                pf_index = int(pg_pf[-1])
                pf, vf, vf_active = pf_index, i, 1
                self.prr_region.append((pid_name, pf, vf, vf_active))

    def write_sim_pkg_lines(self):
        def _write_sim_pkg(host_sr, host_prr):
            sim_pkg_line = []
            for i in range(len(host_prr)-1, -1, -1):
                if i < len(self.prr_region):
                    new_line = f"localparam {host_prr[i]}_PF  = {self.prr_region[i][1]};"
                    sim_pkg_line.append(new_line) 
                    new_line = f"localparam {host_prr[i]}_VF  = {self.prr_region[i][2]};"
                    sim_pkg_line.append(new_line) 
                    new_line = f"localparam {host_prr[i]}_VA  = {self.prr_region[i][3]};"
                    sim_pkg_line.append(new_line) 
                else:
                    new_line = f"localparam {host_prr[i]}_PF  = 0;"
                    sim_pkg_line.append(new_line) 
                    new_line = f"localparam {host_prr[i]}_VF  = 0;"
                    sim_pkg_line.append(new_line) 
                    new_line = f"localparam {n6001_host_prr[i]}_VA = 0;"
                    sim_pkg_line.append(new_line) 
                    
            for i in range(len(host_sr)-1, -1, -1):
                if i < len(self.sr_region):
                    new_line = f"localparam {host_sr[i]}_PF   = {self.sr_region[i][1]};"
                    sim_pkg_line.append(new_line) 
                    new_line = f"localparam {host_sr[i]}_VF   = {self.sr_region[i][2]};"
                    sim_pkg_line.append(new_line) 
                    new_line = f"localparam {host_sr[i]}_VA   = {self.sr_region[i][3]};"
                    sim_pkg_line.append(new_line) 
            return sim_pkg_line

        n6001_host_sr = ["ST2MM", "PF1", "HLB", "VIO", "HPS"] 
        n6001_host_prr = ["HEM", "HEH", "HEM_TG"]
        fm89_host_sr = ["ST2MM", "HLB"]
        fm89_host_prr = []
        fm89_soc_sr =  ["ST2MM"] 
        fm89_soc_prr = ["HEM", "HEH", "HEM_TG"]

        d = {}

        if self.platform == "n6001":
            d['localparams'] = '\n'.join(_write_sim_pkg(n6001_host_sr, n6001_host_prr))
        elif self.platform == "fm89":
            d['localparams'] = '\n'.join(_write_sim_pkg(fm89_host_sr, fm89_host_prr))

        with open(f'templates/{self.platform}/pfvf_sim_pkg_template.txt', 'r') as f:
            src = Template(f.read())
            result = src.substitute(d)
            with open('SampleDevice_sim_pkg.sv', 'w') as fOut:
                fOut.write(result)
        
    def write_scratch_reg_sim_lines(self):
        scratchreg_sim_lines = []
        def is_anonymous(pf, vf):
            if pf == 0:
                return not vf_active and vf not in [0, 1, 2]
            if pf in [1, 2, 3, 4]:
                return not vf_active

            return True

        def gen_sim_lines(index, pf, vf, vf_active):
            # Example: test_csr_access_64(test_result, ADDR64, 'h40018, 0, 0, 5, 0, 'h4018_1050);
            sim_line = (f"test_csr_access_64(test_result, ADDR64, 'h" 
                        f"{index}_0018, 0, "
                        f"{vf_active}, "
                        f"{pf}, "
                        f"{vf}, "
                        f"'h{index}0018{vf_active}{pf}{vf});"
                       )

            return sim_line
        
        for index, port in enumerate(self.sr_region):
            pid, pf, vf, vf_active = port 
            if vf_active == 1:
                is_active = True
            if index > 4:
                scratchreg_sim_lines.append(gen_sim_lines(index, pf, vf, vf_active))
            d =  {'test_csr_access' : '\n'.join(scratchreg_sim_lines[::-1])}
            with open(f'templates/{self.platform}/tester_tests_template.txt', 'r') as f:
                src = Template(f.read())
                result = src.substitute(d)
                with open('SampleDevice_tester_tests.sv', 'w') as fOut:
                    fOut.write(result)
            
    def write_top_cfg_pkg(self):
        def get_mapping_table():
            lines = ['']
            num_port = len(self.sr_region)
            if self.pg_region:
                num_port += 1
            pg_num_port = len(self.pg_region)
            
            # SR region
            for index, value in enumerate(self.sr_region):
                pid_name = value[0]
                lines.append(f'parameter {pid_name} = {index};')
            # PG region
            if self.pg_region:
                pg_id_start = len(self.sr_region)
                for i, pg_pf in enumerate(self.pg_enabled_pfs):
                    pg_id = pg_id_start + i
                    lines.append(f'parameter PG_SHARED_VF_PID = {pg_id};')
    
            # PRR region
            for index, value in enumerate(self.prr_region):
                pid_name = value[0]
                lines.append(f'parameter {pid_name} = {index};')
 
            return lines


        m_lines = get_mapping_table()
       
        d = {'mapping_table':'\n   '.join(m_lines), 
            }
        num_port = len(self.sr_region)
        if self.pg_region:
            num_port += 1

        d['num_host'] = "1"
        d['num_port'] = str(num_port)
        d['pg_num_host'] = "1"
        d['pg_num_port'] = str(len(self.pg_region))
        d['sr_pids'] = ', '.join([str(pid) for pid, _, _, _ in self.sr_region])
        d['sr_pids_idx'] = ', '.join([f'{pid}_IDX' for pid, _, _, _ in self.sr_region])
        d['pg_sr_ports_pf_num'] = ', '.join([str(pf_num) for _, pf_num, _, _ in self.sr_region])
        d['pg_sr_ports_vf_num'] = ', '.join([str(vf_num) for _, _, vf_num, _ in self.sr_region])
        d['pg_sr_ports_vf_active'] = ', '.join([str(vf_active) for _, _, _, vf_active in self.sr_region])

        d['pg_afu_mux_pid'] = ', '.join([str(pid) for pid, _, _, _ in self.prr_region])
        d['pg_afu_mux_pid_idx'] = ', '.join([f'{pid}_IDX' for pid, _, _, _ in self.prr_region])
        d['pg_afu_ports_pf_num'] = ', '.join([str(pf_num) for _, pf_num, _, _ in self.prr_region])
        d['pg_afu_ports_vf_num'] = ', '.join([str(vf_num) for _, _, vf_num, _ in self.prr_region])
        d['pg_afu_ports_vf_active'] = ', '.join([str(vf_active) for _, _, _, vf_active in self.prr_region])

        d['pg_afu_num_ports'] = len(self.prr_region)
        
        pg_pl_depth = ["2" for _ in range(len(self.sr_region))]

        d['pg_pl_depth'] = ', '.join(pg_pl_depth)

        routing_table_lines = ['']
        for index, value in enumerate(self.sr_region):
            pid_name, pf, vf, vf_active = value
            new_line = f"   '{{ pfvf_port:{pid_name}, pf:{pf}, vf:{vf}, vf_active:{vf_active} }},"
            routing_table_lines.append(new_line)
        for index, value in enumerate(self.pg_region):
            pid_name, pf, vf, vf_active = value
            new_line = f"   '{{ pfvf_port:{pid_name}, pf:{pf}, vf:{vf}, vf_active:{vf_active} }},"
            routing_table_lines.append(new_line)
        d['routing_table'] = '\n'.join(routing_table_lines)

        pg_routing_table_lines = ['']
        for index, value in enumerate(self.prr_region):
            pid_name, pf, vf, vf_active = value
            new_line = f"   '{{ pfvf_port:{pid_name}, pf:{pf}, vf:{vf}, vf_active:{vf_active} }},"
            pg_routing_table_lines.append(new_line)
        d['pg_routing_table'] = '\n     '.join(pg_routing_table_lines)
        d['num_rtable_entries'] = self.num_pfs + self.num_vfs + 2
        d['pg_num_rtable_entries'] = len(self.prr_region)
        d['num_pf'] = self.num_pfs
        d['num_vf'] = self.num_vfs

        if self.is_host:
            top_template_file = "top_cfg_pkg_template.txt"
        else:
            top_template_file = "soc_top_cfg_pkg_template.txt"
        with open(f'{os.environ["OFS_ROOTDIR"]}/tools/pfvf_config_tool/templates/{top_template_file}', 'r') as f:
            src = Template(f.read())
            result = src.substitute(d)
            with open(self.top_cfg_file, 'w') as fOut:
                fOut.write(result)

    def get_qsys_gen_command(self):
        line = (f'\nqsys-generate {self.ip_path}/{self.ip_name} --output-directory={self.ip_path}/ '
                f'--pro --simulation --simulator=MODELSIM --simulator=VCS --simulator=VCSMX --clear-output-directory \\\n'
                f'--search-path="$QUARTUS_ROOTDIR/../ip/altera/intel_pcie/ptile /**/*,$QUARTUS_ROOTDIR/../ip/altera/subsystems/pcie_ss/**/*,$"'
               )

        return line 

    def get_ip_deploy_command(self):
        line = (f'ip-deploy --family={self.fpga_family} --part="{self.part}" '
                f'--output-name="{self.output_name}" '
                f'--component-name="{self.component}" '
                f'--output-directory={self.ip_path} '
                f'--search-path="$QUARTUS_ROOTDIR/../ip/altera/intel_pcie/ptile /**/*,$QUARTUS_ROOTDIR/../ip/altera/subsystems/pcie_ss/**/*,$" \\\n'
               )

        return line

    def get_param_from_ip_file(self, line):
        param, value = None, None
        match = re.search('(?<=\=)(.*?)(?=\=)', line) 
        if match:
            param = match.group()
    
        match = re.search('(?<=\")(.*?)(?=\")', line)
        if match:
            value = match.group()
    
        return (param, value)

    def populate_pcie_default_setting(self):
        ip_default_file = f'./pcie_params/pcie_ss_default.sh'
        with open(ip_default_file, 'r') as f:
            ip_default_lines = f.readlines()

        for line in ip_default_lines:
            if (line.find("--component-parameter=") >= 0):
                (param, value) = self.get_param_from_ip_file(line)
                logging.info(f'Populate default params {param} = {value}')
                self.pcie_config_setting[param] = value

    def write_ip_file(self):
        logging.info(f'SELF.NUM_PFS = {self.num_pfs}')
        self.pcie_config_setting = {}
        self.populate_pcie_default_setting() 

        for pcie_param, pcie_param_value in self.PCIE_SS_PARAM.component_params.items():
            if pcie_param == "core16_total_pf_count_hwtcl":
                self.pcie_config_setting[pcie_param] = self.num_pfs
            else:
                self.pcie_config_setting[pcie_param] = pcie_param_value
                logging.info(f"Setting pciec config {pcie_param} to {pcie_param_value}")


        for func, num_vf in self.pf_vf_count.items():
            self.pcie_config_setting[f'core16_{func}_vf_count_hwtcl'] = num_vf

            for pcie_param, pcie_param_value in self.PCIE_SS_PARAM.func_params.items():
                logging.info(f'{pcie_param} - {pcie_param_value} pf:{func} num_vf:{num_vf}')
                key = f'{pcie_param.format(func_num=func)}'
                
                if pcie_param == "core16_{func_num}_bar0_address_width_user_hwtcl" and func == "pf0":
                    pcie_param_value = 20
                #if num_vf > 0 and pcie_param in PCIE_SS_PARAM.multi_vfs_func_params:
                if num_vf > 0:
                    if pcie_param == "core16_exvf_msix_tablesize_{func_num}":
                        pcie_param_value = 6
                    elif pcie_param == "core16_exvf_msixtable_offset_{func_num}":
                        pcie_param_value = 1536
                    elif pcie_param == "core16_exvf_msixtable_bir_{func_num}":
                        pcie_param_value = 4
                    elif pcie_param == "core16_exvf_msixpba_offset_{func_num}":
                        pcie_param_value = 1550
                if num_vf > 0 and pcie_param in self.PCIE_SS_PARAM.multi_vfs_func_params:
                    if pcie_param == "core16_{func_num}_sriov_vf_bar0_address_width_hwtcl" and func == "pf0":
                        pcie_param_value = 20
                    else:
                        pcie_param_value = self.PCIE_SS_PARAM.multi_vfs_func_params[pcie_param]
                self.pcie_config_setting[key] = pcie_param_value
                logging.info(f'Assigned {key} - {pcie_param_value} for pf:{func} num_vf:{num_vf}')

        ip_file_lines = []

        # Include the quartus ini command
        ip_file_lines.append("echo \"debug_features_enablement_full=1\" >" + self.ip_path +"/quartus.ini\n")

        # Append the ip-deploy command
        ip_file_lines.append(self.get_ip_deploy_command())

        # Add all the settings back to the list
        # for param in ip_file_class.pcie_default_settings:
        ip_param_lines = []
        for param, value in self.pcie_config_setting.items():
            ip_param_lines.append(f'   --component-parameter={param}="{value}"')

        ip_file_lines.extend(' \\\n'.join(ip_param_lines))
        
        # Append the qsys-generate command
        ip_file_lines.append(self.get_qsys_gen_command())

        # Write the new lines back to the ip-deploy file
        with open(f'{os.environ["OFS_ROOTDIR"]}/ipss/pcie/qip/{self.output_name}.sh', 'w+') as ip_sh_file:
            ip_sh_file.writelines(ip_file_lines)

        
        res = os.system(f'sh {os.environ["OFS_ROOTDIR"]}/ipss/pcie/qip/{self.output_name}.sh')

        ## Update simulation file lists
        #if (res == 0):
        #    os.system(f'sh {os.path.join(os.environ["OFS_ROOTDIR"], GEN_FILE_PATHS.gen_sim_files)} {self.platform}')
        #    logging.info("Success!  Thank you for using the IP-Deploy Tool")
        #else:
        #    logging.info("Error detected!  Please check output for more info")

def main():
    # Setup Procedures
    configure_logging()
    args = process_input_arguments()
    logging.info("=============================================")
    logging.info("Beginning FIM Configuration Tool")
    logging.info("=============================================")

    curr_device = Device()
    curr_device.process_configuration(args.ini)
    curr_device.write_top_cfg_pkg() 
    curr_device.write_ip_file()


if __name__ == '__main__':
    main()
