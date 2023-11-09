# IP Configuration Parameter Database

The scripts here manage the flow of Platform Designer IP parameters into Verilog header files, making it possible for OFS RTL to react to changes in IP. The generated "database" is a collection of header files containing only preprocessor macros. Macros are used instead of SystemVerilog packages and parameters in order to allow RTL to test whether a parameter is defined, using ifdef.

All generated files are stored in a subdirectory of a project's build root named "ofs_ip_cfg_db". This directory is on the search path of every build. The scripts generate a wrapper file that includes the entire collection of include files. RTL should include the entire collection with:

```Verilog
`include "ofs_ip_cfg_db.vh"
```

The way macros are used is IP dependent. For a clock, the frequency is available as the value of macro:

```Verilog
`define OFS_FIM_IP_CFG_SYS_CLK_CLK0_NAME     clk_sys
`define OFS_FIM_IP_CFG_SYS_CLK_CLK0_MHZ      470.0
`define OFS_FIM_IP_CFG_SYS_CLK_CLK0_MHZ_INT  470  // Nearest integer frequency
```

A macro might also be used to detect whether a feature is configured, such as testing whether a particular PCIe PF is enabled:

```Verilog
`ifdef OFS_FIM_IP_CFG_PCIE_SS_PF3_ACTIVE
   ... Do something ...
`endif
```

## Generating the Parameter Include Files

The ofs_ip_cfg_db directory does not exist at the start of compilation. The directory and its contents are created at the end of the quartus_ipgenerate phase -- just before synthesis -- by the [gen_ofs_ip_cfg_db.tcl](gen_ofs_ip_cfg_db.tcl) and [ofs_ip_cfg_db.tcl](ofs_ip_cfg_db.tcl) scripts.

OFS instantiates a global post-module hook, [ofs_post_module_script_fim.tcl](../ofs_post_module_script_fim.tcl), that is invoked at the end of every module in the standard Quartus build flow. After quartus_ipgenerate, the first step in the standard flow, the hook invokes gen_ofs_ip_cfg_db.tcl and the include files are built. Generated files are updated as needed on subsequent compilations.

### Quartus Project Setup

Add the configuration manager at the start of every OFS project. Specify ofs_ip_cfg_db.tcl early because it creates a Tcl namespace that must exist before IP is added to the project.

```Tcl
# Load this first. The script manages a database of IP from which parameters will
# be extracted before synthesis. The parameters are written to header files in
# ofs_ip_cfg_db/.
set_global_assignment -name SOURCE_TCL_SCRIPT_FILE "$::env(BUILD_ROOT_REL)/ofs-common/scripts/common/syn/ip_get_cfg/ofs_ip_cfg_db.tcl"

# Add the constructed IP database to the search path. It will be populated
# by a hook at the end of ipgenerate
set_global_assignment -name SEARCH_PATH "ofs_ip_cfg_db"
```

Within the ::ofs_ip_cfg_db namespace, the script defines a dictionary that will hold pointers to IP. It also defines procedures for orchestrating header file creation.

### Adding IP to Parse

IP can be added to a Quartus project at any point after ofs_ip_cfg_db.tcl is sourced. We recommend updating the IP dictionary next to the IP_FILE assignment. For example, a system with two PCIe SS instances might have:

```Tcl
set_global_assignment -name IP_FILE ../ip_lib/ipss/pcie/qip/pcie_ss.ip
set_global_assignment -name IP_FILE ../ip_lib/ipss/pcie/qip/soc_pcie_ss.ip
 
# Add the PCIe SS to the dictionary of IP files that will be parsed by OFS
# into the project's ofs_ip_cfg_db directory. Parameters from the configured
# IP will be turned into Verilog macros.
dict set ::ofs_ip_cfg_db::ip_db ../ip_lib/ipss/pcie/qip/pcie_ss.ip [list pcie_ss pcie_ss_get_cfg.tcl]
dict set ::ofs_ip_cfg_db::ip_db ../ip_lib/ipss/pcie/qip/soc_pcie_ss.ip [list soc_pcie_ss pcie_ss_get_cfg.tcl]
```

"dict set" is standard Tcl syntax. The first argument is the dictionary, the second the key and the third the value. The parameter parsing script expects keys to be relative paths to IP files. Values are two element lists. The first element is a unique name to use for the generated macros. It will be used unmodified in the header file name and capitalized in the middle of macros following "OFS_FIM_IP_CFG_". The second element is the name of the IP-specific script that will handle the parameter mapping. The script name may be a full path to a script, anywhere in the file system. It may also be the name of a Tcl script in this ip_get_cfg directory.

### IP-Specific Parsers

At the lowest level, an IP-specific script is required that maps Platform Designer internal parameters to sensible Verilog macros. Scripts for standard IP are provided here, such as parsers for [IOPLLs](iopll_get_cfg.tcl) and the [PCIe Subsystem](pcie_ss_get_cfg.tcl). The collection is extensible and designers may write new scripts as needed.

The main challenge when writing a new script is discovering IP's internal parameter names. One way to find the names is to run the Platform Designer GUI. Parameter names are displayed when hovering over input boxes. Alternatively, the export_hw_tcl procedure available in qsys-script will dump the entire namespace to a file as a list of Tcl assignments.

For example, this command generates a hw_tcl file for a PCIe SS IP file in a project named ofs_top when run in the Quartus project directory:

```sh
qsys-script --quartus-project=ofs_top --system-file=../ip_lib/ipss/pcie/qip/pcie_ss.ip --cmd="package require qsys; export_hw_tcl"
```

## Sample Output

The following are examples of IP-specific output files written to a project's ofs_ip_cfg_db directory.

### Clocks (IOPLL)

```Verilog
//
// Generated by OFS script iopll_get_cfg.tcl using qsys-script
//

`ifndef __OFS_FIM_IP_CFG_SYS_CLK__
`define __OFS_FIM_IP_CFG_SYS_CLK__ 1

//
// Clock frequencies and names
//
`define OFS_FIM_IP_CFG_SYS_CLK_CLK0_NAME     clk_sys
`define OFS_FIM_IP_CFG_SYS_CLK_CLK0_MHZ      470.0
`define OFS_FIM_IP_CFG_SYS_CLK_CLK0_MHZ_INT  470  // Nearest integer frequency

`define OFS_FIM_IP_CFG_SYS_CLK_CLK1_NAME     clk_100m
`define OFS_FIM_IP_CFG_SYS_CLK_CLK1_MHZ      100.0
`define OFS_FIM_IP_CFG_SYS_CLK_CLK1_MHZ_INT  100  // Nearest integer frequency

`define OFS_FIM_IP_CFG_SYS_CLK_CLK2_NAME     clk_1x
`define OFS_FIM_IP_CFG_SYS_CLK_CLK2_MHZ      175.0
`define OFS_FIM_IP_CFG_SYS_CLK_CLK2_MHZ_INT  175  // Nearest integer frequency

`define OFS_FIM_IP_CFG_SYS_CLK_CLK3_NAME     clk_ptp_slv
`define OFS_FIM_IP_CFG_SYS_CLK_CLK3_MHZ      155.555556
`define OFS_FIM_IP_CFG_SYS_CLK_CLK3_MHZ_INT  156  // Nearest integer frequency

`define OFS_FIM_IP_CFG_SYS_CLK_CLK4_NAME     clk_50m
`define OFS_FIM_IP_CFG_SYS_CLK_CLK4_MHZ      50.0
`define OFS_FIM_IP_CFG_SYS_CLK_CLK4_MHZ_INT  50  // Nearest integer frequency

`endif // `ifndef __OFS_FIM_IP_CFG_SYS_CLK__
```

### PCIe Subsystem

```Verilog
//
// Generated by OFS script pcie_ss_get_cfg.tcl using qsys-script
//

`ifndef __OFS_FIM_IP_CFG_PCIE_SS__
`define __OFS_FIM_IP_CFG_PCIE_SS__ 1

//
// The OFS_FIM_IP_CFG_<ip_name>_PF<n>_ACTIVE macro will be defined iff the
// PF is active. The value does not have to be tested.
//
// For each active PF<n>, OFS_FIM_IP_CFG_<ip_name>_PF<n>_NUM_VFS will be
// defined iff there are VFs associated with the PF.
//
`define OFS_FIM_IP_CFG_PCIE_SS_PF0_ACTIVE 1
`define OFS_FIM_IP_CFG_PCIE_SS_PF0_BAR0_ADDR_WIDTH 20
`define OFS_FIM_IP_CFG_PCIE_SS_PF0_NUM_VFS 3
`define OFS_FIM_IP_CFG_PCIE_SS_PF0_VF_BAR0_ADDR_WIDTH 20

`define OFS_FIM_IP_CFG_PCIE_SS_PF1_ACTIVE 1
`define OFS_FIM_IP_CFG_PCIE_SS_PF1_BAR0_ADDR_WIDTH 12

`define OFS_FIM_IP_CFG_PCIE_SS_PF2_ACTIVE 1
`define OFS_FIM_IP_CFG_PCIE_SS_PF2_BAR0_ADDR_WIDTH 18

`define OFS_FIM_IP_CFG_PCIE_SS_PF3_ACTIVE 1
`define OFS_FIM_IP_CFG_PCIE_SS_PF3_BAR0_ADDR_WIDTH 12

`define OFS_FIM_IP_CFG_PCIE_SS_PF4_ACTIVE 1
`define OFS_FIM_IP_CFG_PCIE_SS_PF4_BAR0_ADDR_WIDTH 12


//
// The macros below represent the raw PF/VF configuration above in
// ways that are easier to process in SystemVerilog loops.
//

// Total number of PFs, not necessarily dense (see MAX_PF_NUM)
`define OFS_FIM_IP_CFG_PCIE_SS_NUM_PFS 5
// Total number of VFs across all PFs
`define OFS_FIM_IP_CFG_PCIE_SS_TOTAL_NUM_VFS 3
// Largest active PF number
`define OFS_FIM_IP_CFG_PCIE_SS_MAX_PF_NUM 4
// Largest number of VFs associated with a single PF
`define OFS_FIM_IP_CFG_PCIE_SS_MAX_VFS_PER_PF 3

// Vector indicating enabled PFs (1 if enabled) with
// index range 0 to OFS_FIM_IP_CFG_PCIE_SS_MAX_PF_NUM
`define OFS_FIM_IP_CFG_PCIE_SS_PF_ENABLED_VEC 1, 1, 1, 1, 1
// Vector with the number of VFs indexed by PF
`define OFS_FIM_IP_CFG_PCIE_SS_NUM_VFS_VEC 3, 0, 0, 0, 0

`endif // `ifndef __OFS_FIM_IP_CFG_PCIE_SS__
```
