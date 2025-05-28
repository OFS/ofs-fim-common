# Platform Designer SystemVerilog Wrappers

Platform Designer (PD) projects and IP describe exported ports hierarchically, with every port contained inside an interface. The PD-generated Verilog and VHDL top-level wrappers drop the interfaces because both languages have syntax only for ports. SystemVerilog adds language-level syntax for interfaces. The [ip_gen_sv_wrapper.tcl](ip_gen_sv_wrapper.tcl) script is a prototype for future support of SystemVerilog wrapper generation as a third output target in PD.

The wrapper generator script does the following:

* Generate a SystemVerilog (SV) wrapper for every exported interface that has more than one port.
* Generate a new top-level SV module with signals wrapped by the SV interfaces.
* Detect top-level SV module ports that naturally map to vectors of interfaces or ports. For example, multiple HSSI streams with the same interface can be a single vector. Static elaboration with *for* loops can then be used in RTL. The algorithm for detecting vectors is described below in [heuristics for discovering vectors](#heuristics-for-discovering-vectors).

In addition to the new SystemVerilog wrapper features, the script adds new generated files that describe the PD configuration:

* A header file with macros derived from the IP configuration HWTCL. For example, macros emitted for PCIe IP export the values of configuration set in the GUI such as MSI-X table size and SR-IOV configuration. RTL that includes the header file can adapt to the IP configuration with either static elaboration or preprocessing.
* A header file with macros for each SystemVerilog interface generated for the SV wrapper. Macros indicate the existence of each interface, the width of each symbol and the sizes of ports that are mapped to vectors.

## Running the script

The script does not depend on any early Quartus phases. It may be run before or after IP generation. Run it with:

```bash
qsys-script --cmd="source <path to>/ip_gen_sv_wrapper.tcl; gen_sv_wrapper <output directory>" \
    --quartus-project="<project name>" --rev="<project revision>" \
    --search-path="<comma separated IP search path (optional)>" \
    --system-file="<path to IP or QSYS file>"
```

Five files will be generated in the output directory. Each file name begins with the name extracted from the IP file. For IP named mem_ss, the files would be:

* [mem_ss_**sv.sv**](#systemverilog-wrapper-_sv_wrappersv) - The top-level SV wrapper module and interface declarations.
* [mem_ss_**param_pkg.sv**](#systemverilog-parameter-package-_param_pkgsv) - SV parameter package with port vector width parameters.
* [mem_ss_**if_info.vh**](#systemverilog-interface-macros-_if_infovh) - Macros describing interfaces, including symbol widths.
* [mem_ss_**ip_params.vh**](#systemverilog-interface-macros-_ip_paramsvh) - Macros derived from the IP HWTCL configuration.
* mem_ss_**sv.log** - Log file for debugging the script.

#### Search path

qsys-script depends on the \-\-search\-path argument in order to refer to IP or other QSYS projects from the top-level system file. Quartus projects normally hold the IP search path in the global assignment named IP_SEARCH_PATHS. qsys-script does not load search paths automatically, even when the Quartus project is specified. The ip_gen_sv_wrapper.tcl script detects missing dependencies and raises an error.

#### SystemVerilog wrapper: \*\_sv\_wrapper.sv

The wrapper begins with generated interfaces. Interface names are derived from the names within the IP:

```
<ip name>_<interface name>_if
```

For example, the pins for DDR4 may be:

```SystemVerilog
interface mem_ss_mem_ddr4_if;
  logic [16:0] a;
  logic act_n;
  logic alert_n;
  logic [1:0] ba;
  logic [1:0] bg;
  logic cke;
  logic cs_n;
  wire  [3:0] dbi_n;
  wire  [31:0] dq;
  wire  [3:0] dqs_c;
  wire  [3:0] dqs_t;
  logic odt;
  logic par;

  modport ip (
    input  alert_n,
    output a, act_n, ba, bg, cke, cs_n, odt, par,
    inout  dbi_n, dq, dqs_c, dqs_t
  );
  modport app (
    input  a, act_n, ba, bg, cke, cs_n, odt, par,
    output alert_n,
    inout  dbi_n, dq, dqs_c, dqs_t
  );
endinterface
```

The "ip" modport always connects inside the generated IP.

When PD declares an associated clock or reset, symbols named clk or rst/rst_n are added to generated interfaces. They are assigned to the corresponding clock and reset inside the wrapper module.

The generated wrapper module that RTL should instantiate is in the same file. PD interfaces with only one port remain simple ports without interfaces. Similarly named ports with matching types are converted to vectors. For example:

```SystemVerilog
module mem_ss_sv
  import mem_ss_param_pkg::*;
(
  input  wire [NUM_PORTS-1:0] mem_pll_ref_clk,
  input  wire [NUM_PORTS-1:0] mem_oct_rzqin,
  mem_ss_mem_ddr4_if.ip mem_ddr4[NUM_PORTS-1:0],
  output wire [NUM_PORTS-1:0] mem_ss_app_usr_clk,
  output wire [NUM_PORTS-1:0] mem_ss_app_usr_reset_n,
  mem_ss_subsystem_reset_if.ip subsystem_reset,
  mem_ss_i_axi_mm_if.subordinate i_axi_mm[NUM_PORTS-1:0],
  mem_ss_mem_status_if.ip mem_status[NUM_PORTS-1:0]
);
```

#### SystemVerilog parameter package: \*\_param\_pkg.sv

This generated package holds only localparams with sizes of vector ports. The heuristic used to map ports to vectors is described below.

#### SystemVerilog interface macros: \*\_if\_info.vh

RTL that includes the interface macros can check whether a particular interface exist, whether a symbol exists within an interface, and the width of a symbol. When an interface exists, the HAS_IFC macro is defined:

```SystemVerilog
`define HAS_IFC_MEM_SS_MEM_DDR4_IF 1
```

When a symbol exists within an interface, a macro is set to its width:

```SystemVerilog
`define IFC_MEM_SS_MEM_DDR4_IF_WIDTH_A 17
```

Macros are also defined indicating the top-level module's port names. For each port name there is a macro:

```SystemVerilog
`define MEM_SS_HAS_PORT_MEM_DDR4 1
```

A macro is defined when the port is an interface, set to the interface type:

```SystemVerilog
`define MEM_SS_PORT_MEM_DDR4_IS_SV_IFC mem_ss_mem_ddr4_if
```

When a port is a vector, a macro is set to the localparam with its width:

```SystemVerilog
`define MEM_SS_PORT_MEM_DDR4_IS_VEC mem_ss_param_pkg::NUM_PORTS
```

#### SystemVerilog interface macros: \*\_ip\_params.vh

The IP params include file defines macros based on the IP's HWTCL variables. For example:

```SystemVerilog
`define PCIE_SS_PARAM_CORE16_PF0_PCI_MSIX_BIR_HWTCL    4
`define PCIE_SS_PARAM_CORE16_PF0_PCI_MSIX_PBA_HWTCL    4
`define PCIE_SS_PARAM_CORE16_PF0_PCI_MSIX_PBA_OFFSET_HWTCL    1550
`define PCIE_SS_PARAM_CORE16_PF0_PCI_MSIX_TABLE_OFFSET_HWTCL    1536
`define PCIE_SS_PARAM_CORE16_PF0_PCI_MSIX_TABLE_SIZE_HWTCL    6
```

They are direct mappings from HWTCL variables used in a way that wasn't the original intent of the HWTCL, so may be unnecessarily complex. Still, the information can be valuable when writing RTL that adapts to IP configuration.

## Heuristics for discovering vectors

### Port naming

There is currently no data structure in Platform Designer to describe vectors of ports in the top-level wrapper. In the current PD, there is a 1:1 mapping from interface objects containing ports to top-level module ports. For now, the SystemVerilog wrapper script must infer vectors from port names and interface symbol lists. If you are building a PD project and planning to generate a SV wrapper, choose exported port names that match the vector discovery heuristic.

The search for vector candidates begins by matching top-level port names with a zero in them, either of the form \*0\_\* (e.g. mem0_ddr4) or ending in zero. When other port names are found matching the form with monotonically increasing integers, the group of ports becomes a vector. This is true both for simple top-level ports of type wire and for top-level ports that are interfaces.

Even a singleton port name matching the zero patterns with no one pattern becomes a vector with a single entry. Namely, mem0_ddr4 is found but mem1_ddr4 is not. This is for consistency. The script has no way to know whether the port could become a vector if more instances of the type were added, such as PCIe IP that can be configured with slot bifurcation. By always defining a vector, RTL can employ static elaboration and loops, even for the case of a single entry.

All entries in a vector share the same type. When the script finds a pattern match it then confirms that the types are identical. If the types do not match the ports are separated into groups. The script standardizes the naming of both interface and port groups by adding "\_g\<number\>" to groups one and above. For example, consider a board with four DDR4 DIMMs where two of the DIMMs have ECC and two do not. If the first two DDR4 pin interfaces are named mem0_ddr4 and mem1_ddr4 and the second pair of interfaces are mem2_ddr4 and mem3_ddr4, the script will do the following:

* Detect that mem0 and mem1 have identical interfaces, as do mem2 and mem3.
* Emit two interface definitions: mem_ss_mem_ddr4_if and mem_ss_mem_g1_ddr4_if.
* Add two ports to the top level wrapper, where each port is a two entry vector: mem_ddr4 and mem_g1_ddr4.

The script would continue with mem_g2_ddr4 if yet another type variation is found.

The macros created in if_info.vh follow the same naming pattern. When a group 1 exists there are corresponding g1 macros.

### Vector size naming

The names for vector size localparams in the generated params_pkg.sv file must also be inferred. The script computes a histogram of vector sizes and names the size found most frequently "NUM_PORTS". This is clearly not ideal, but is frequently correct. Other localparam vector size names are derived from the names of the ports. Ultimately, PD will need to add explicit data structures for describing port vectors.

To work around the unpredictable vector size naming, take advantage of the interface macros in the generated if_info.vh file. The macro names are predictable functions of port names. For example:

```SystemVerilog
`define MEM_SS_PORT_MEM_DDR4_IS_VEC mem_ss_param_pkg::NUM_MEM_DDR4
`define MEM_SS_PORT_MEM_G1_DDR4_IS_VEC mem_ss_param_pkg::NUM_MEM_G1_DDR4
```

In this case the parameter names were chosen well, but they could be anything and the macro would still indicate the proper value. RTL could define its own localparam through the macro.
