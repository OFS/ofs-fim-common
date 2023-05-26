# Pfvf Configuration Tool

## Overview
This tool allows the platform designer to select any configuration
of PFs and VFs in the PF/VF Mux (pf_vf_mux_top.sv) by modifying 
the corresponding API package file (top_cfg_pkg.sv).

The tools' features are six-fold:

1. Update the PF/VF Mux API
2. Add/remove AFU endpoints
   a. PF0 VFs - afu_main.port_afu_instances
   b. All other functions: afu_top.fim_afu_instances
   c. New AFUs will be instiated as HE-NULL (he_null.sv) AFUs.
3. Update the pcie_ss.sh "ip-deploy" file
4. Generate the new pcie_ss.ip file

## Configuring Design
### INI File - Selecting the desired PF/VF configuration
- Edit the INI *.ofss file.
- INI file can be found under the corresponding platforms' tool/pfvf_tool_config directory
- Specify platform and fim version under 'Project Settings'
- Specify it is a host device you're configuring
- Specify the desired number of PFs by using the INI file format; each desired PF is encapsulated by
   brackets.
- For each PF, select the number of AFUs by setting "num_vfs = X'.  
- An example of a user who wants 6 PFs with 4 VFs on PF0, 1 VF on PF2, and 2 VFs on PF3 is as follows
- For N6001, or F2000x's SOC, set"pg_enable" to True to indicate port gasket availability on PF0

```
   ; OFS Settings file example
   [ProjectSettings]
   platform = n6001
   fim = base_x16
   IpDeployFile = pcie_ss.sh
   IpFile = pcie_ss.ip
   OutputName = pcie_ss
   ComponentName = pcie_ss
   is_host = True

   [pf0]
   num_vfs = 4
   pg_enable = True

   [pf1]

   [pf2]
   num_vfs = 1

   [pf3]
   num_vfs = 2

   [pf4]

   [pf5]
----------------------------------
```

### Required Input File
- INI file

### Generated/Modfied Files
- src/afu_top/mux/top_cfg_pkg.sv
- ipss/pcie/qip/ss/pcie_ss.ip

## Running Tool
- To generate HW source code files
`python3 gen_ofs_settings.py --ini <ini file>`

## Running Simulation Test
- For basic simulation test, please run the corresponding platform's "sim/unit_test/pfvf_test/run.sh"


## Limitations
 - 0 virtual functions on PF0 is not supported. This is because
   the PRR region cannot be left unconnected.  A loopback may need
   to be instantiated in this special case. 
