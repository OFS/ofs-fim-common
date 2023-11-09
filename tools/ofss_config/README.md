# OFSS Config Tool

## Overview
This tool currently supports the following IP Subsystem configurations

IP | Configurable Parameters|  
------------- | -------------
IOPLL | p_clk frequency
PCIe Subsystem | # of pfs, vfs, bar address widths, etc
Memory Subsystem | memory presets
HSSI Subsystem | # of channels, data rates

- Configurations are provided for reference boards.  
- Board specific information is part of the OFSS base file.
- Subsystem configurations are board independent.  For more details, please refer to corresponding README documents

## Configuring the Design

### OFSS Files 
- Each IP (IOPLL, PCIe, Memory, HSSI) can be configured with its corresponding OFSS file.  These files are located in the corresponding platform's `tools/ofss_config/<IP>` directory
- Each platform has its own OFSS wrapper file, that will include the platform's settings, and the desired IP OFSS files. Please see `<platform>@commit/tools/ofss_config/README.md` for more details.


## To run OFSS Config Tool
`$ python3 gen_ofs_settings.py --ofss <OFSS Files, comma or space separated>  [--target <$WORKDIR>] [--debug]`

Examples:

`$ python3 ${OFS_ROOTDIR}/ofs-common/tools/ofss_config/gen_ofs_settings.py --ofss n6001_base.ofss,pcie/pcie_host.ofss,iopll/iopll.ofss,memory/memory.ofss,hssi/hssi_8x25g.ofss`

`$ python3 ${OFS_ROOTDIR}/ofs-common/tools/ofss_config/gen_ofs_settings.py --ofss "n6001.ofss /hssi/hssi_8x25.ofss" --target ../../../..`



### Required setup and input files
- OFSS files
- One of the OFSS files must contain project settings info (includes info on fim_name, device_id, part number).
- Please have `$OFS_ROOTDIR` set up

### Configuration Summary
Summary of all IP configurations can be found in similar STDOUT ouput:

```
ofs
	settings:
		platform : n6001
		family : agilex
		fim : base_x16
		part : AGFB014R24A2E2V
		device_id : 6001
		p_clk : 470
hssi
	settings:
		output_name : hssi_ss
		num_channels : 8
		data_rate : 25GbE
pcie
	settings:
		output_name : pcie_ss
	pf0:
		num_vfs : 3
		bar0_address_width : 20
		vf_bar0_address_width : 20
	pf1:
	pf2:
		bar0_address_width : 18
	pf3:
	pf4:
iopll
	settings:
		output_name : sys_pll
		instance_name : iopll_0
	p_clk:
		freq : 470
memory
	settings:
		output_name : mem_ss_fm
		preset : n6001

```

### Generated/Modfied Files
Once the tool completes configuration, there will be a summary section providing the paths of all modified IP files

Here's an example of where the modified ip files will likely be:

```
OFS IP Configuration Tool Complete for:
['<$WORKDIR path to>/tools/ofss_config/ofs_settings, <$WORKDIR>/tools/ofss_config/hssi_8x10.ofss']
Updated the following:
         - <$WORKDIR>ofs-common/src/fpga_family/agilex/sys_pll/sys_pll.ip
         - <$WORKDIR>ipss/pcie/qip/pcie_ss.ip
         - <$WORKDIR>ipss/mem/qip/mem_ss/mem_ss_fm.ip
         - <$WORKDIR>ipss/mem/qip/ed_sim/ed_sim_mem.ip
         - <$WORKDIR>ipss/hssi/qip/hssi_ss/hssi_ss.ip
```

### Debug Feature
`--debug` flag available to log all IP Deploy Commands to "ip_deploy_cmds.log" for post analysis.
