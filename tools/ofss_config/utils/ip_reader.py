import argparse
import logging
import logging.handlers
import os
import sys
import xml.etree.ElementTree as ET

IP_ROOT_CHILDREN = {
    'vendor' : 0,
    'library': 1, 
    'name': 2, 
    'version': 3, 
    'bus_interfaces': 4, 
    'model': 5, 
    'vendor_extensions': 6
}

VENDOR_EXT_CHILDREN = {
    'entity_info': 0, 
    'altera_module_parameters': 1, 
    'altera_system_parameters': 2, 
    'altera_interface_boundary': 3, 
    'altera_has_warnings': 4, 
    'altera_has_errors': 5
}

PARAM_CHILDREN = {
    'name': 0, 
    'display_name': 1, 
    'value': 2
}

class AlteraParameter:
    def __init__(self, parameter, parameter_type):
       self.name = parameter[PARAM_CHILDREN['name']].text
       self.parameter_type = parameter_type
       self.display_name = parameter[PARAM_CHILDREN['display_name']].text
       self.id = parameter.attrib['parameterId']
       self.type = parameter.attrib['type']
       self.value = parameter[PARAM_CHILDREN['value']].text if parameter[PARAM_CHILDREN['value']].text else None

    def get_info(self):
        return f"{self.value} ({self.type})"

class IPFile:
    def __init__(self, ip_file):
        self.ip_file = ip_file
        self.root = self.get_ip_root()

        # Root Children: 
        self.vendor = self.root[IP_ROOT_CHILDREN['vendor']].text
        self.library = self.root[IP_ROOT_CHILDREN['library']].text
        self.name = self.root[IP_ROOT_CHILDREN['name']].text
        self.version = self.root[IP_ROOT_CHILDREN['version']].text
        self.bus_interfaces = self.root[IP_ROOT_CHILDREN['bus_interfaces']]
        self.model = self.root[IP_ROOT_CHILDREN['model']]
        self.vendor_extensions = self.root[IP_ROOT_CHILDREN['vendor_extensions']]

        # Vendor Extensions:
        self.altera_module_parameters = self.get_parameters('altera_module_parameters')
        self.altera_system_parameters = self.get_parameters('altera_system_parameters')
        
        # IP Info
        self.ip_info = {}
        self.get_ip_info()

    def get_ip_root(self):
        tree = ET.parse(self.ip_file)
        root = tree.getroot()

        return root

    def get_ip_info(self):
        information = ['device', 'deviceFamily', 'deviceSpeedGrade', 'generationId']
        for info in information:
            self.ip_info[info] = self.altera_system_parameters[info].value

    def dump_ip_info(self):
        logging.info(f'IP: {self.name}')
        for k, v in self.ip_info.items():
            logging.info(f'\t{k}: {v}')

    def get_parameters(self, parameter_type):
        parameters = {}
    
        for parameter in self.vendor_extensions[VENDOR_EXT_CHILDREN[parameter_type]][0]:
            curr_param = AlteraParameter(parameter, parameter_type)
            parameters[curr_param.name] = curr_param

        return parameters

    def dump_to_log(self):
        sorted_module_parameters = sorted(self.altera_module_parameters.keys()) 
        sorted_system_parameters = sorted(self.altera_system_parameters.keys()) 
        with open(f"{self.name}_readable.ip", "w") as fOut:
            fOut.write("**********\n")
            fOut.write(f"IP INFO - {self.name}\n")
            fOut.write("**********\n")
            fOut.write(f"IP: {self.name}\n")
            for k, v in self.ip_info.items():
                fOut.write(f'{k}: {v}\n')

            fOut.write("\n\n")
            fOut.write("**********\n")
            fOut.write("MODULE PARAMETERS\n")
            fOut.write("**********\n")
            for param in sorted_module_parameters:
                fOut.write(f"{param}: {self.altera_module_parameters[param].get_info()}\n")
            fOut.write("\n\n")

            fOut.write("**********\n")
            fOut.write("SYSTEM PARAMETERS\n")
            fOut.write("**********\n")
            for param in sorted_system_parameters:
                fOut.write(f"{param}: {self.altera_system_parameters[param].get_info()}\n")

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

def process_input_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--ip",
        dest="ip",
        nargs="+",
        type=str,
        required=True,
        help="Input IP file to read",
    )

    return parser.parse_args()

def process_ip_files(ip_file_list):
    ips = []

    for ip_string in ip_file_list:
        ip_elems = ip_string.split(",")
        for ip in ip_elems:
            if ip:
                ip_abs_path = os.path.abspath(ip)
                ips.append(IPFile(ip_abs_path))

    return ips
        
def main():
    # Setup Procedures
    configure_logging()
    args = process_input_arguments()

    ips = process_ip_files(args.ip)
    
    for ip in ips:
        ip.dump_ip_info()
        ip.dump_to_log()

if __name__ == "__main__":
    main()
