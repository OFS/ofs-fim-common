# OFS Common Directory

This directory contains resources that may be used across the board-specific repositories contained in the directory above.

A symbolic link to this directory exists within each of the development repositories so that directory traversal outside of the board-specific repository is not required.

Contained in this directory are the following:

## Directories

### Scripts (***scripts***)
   - Contains:
      - Simulation scripts required to set up file lists for IP and subsystems contained in the board-specific repo. (***common/sim***)
* [Simulation Script README](scripts/common/sim/readme.txt) Contains the setup and execution instructions for running the simulation scripts.
      - Synthesis scripts that run the complete FPGA synthesis and post-processing flow. (***common/syn***)
* [Synthesis Script README](scripts/common/syn/README) Contains the setup and execution instructions for running the synthesis flow.
      - FPGA family-specific scripts. (***fpga\_family***)
         - This directory will contain any scripts that are specific to an FPGA family, but not necessarily a specific board.
         - For example, for scripts common to the Agilex FPGA family, they will be contained in ***fpga\_family/agilex***.
### Source Code (***src***)
   - This directory contains source code that may be used across different board-specific repositories.
#### Common Device-Independent Source Code (***src/common***)
   - Source code contained in this directory may be used in designs without regard to the FPGA device or board used.
   - Contained here are:
      - AFU Top-level code (***src/common/afu\_top***): Supporting blocks for management of the Accelerated Functional Unit (AFU).
      - Copy Engine (***src/common/copy\_engine***): Documentation and code in support of the Copy Engine including the top-level, Control and Status Registers (CSRs), and AXI Bus interfaces.
      - Function-Level Reset (FLR) (***src/common/flr***): Contained here is the code and supporting Tcl script to enable the use of PCIe FLR.
      - FPGA Management Engine (FME) (***src/common/fme***): Supporting data structures, CSR definitions, and RTL for AXI Bus interface.
      - FME Identification ROM (***src/common/fme\_id\_rom***): ROM containing identification information for driver and host software.
      - Host Exerciser (HE) High-Speed Serial Interface (HSSI) (***src/common/he\_hssi***): This directory contains a variety of code and supporting resources related to the Ethernet interface and the host exerciser logic associated with it.
      - Host Exerciser (HE) Loopback (LB) (***src/common/he\_lb***): The Host Exerciser Loopback AFU is a traffic generator that can be attached both to host memory, often over PCIe, and to local memory, such as board-attached DDR. It can test the correctness and throughput of memory channels.
* [Host Exerciser Loopback README](src/common/he_lb/README.md) Thorough description of the Host Exerciser and its subdirectories.
      - Host Exerciser (HE) Null (***src/common/he\_null***): The Host Exercisor Null is a very basic "null" termination block for the AFU.
      - Includes Directory (***src/common/includes***): This directory contains a variety of common packages, interfaces, and defines that are used throughout the FIM design.
      - MSIX Interrupts (***src/common/interrupt***): Code supporting the MSIX interrupt implementation in the FIM is located in this directory.
      - Library of Basic Components (***src/common/lib***): This directory contains a number of basic components that are used throughout the FIM like AXI Interfaces, FIFOs, MUXs, RAM blocks, and clock domain-crossing synchronizers.
      - DDR4 Memory Test-Pattern Generator (TG) (***src/common/mem\_tg***): This is the test-pattern generator used with a number of example DDR4 example designs.  This code is functionally the same and has an interface that is compatible with the FIM.
      - Port Gasket (***src/common/port\_gasket***): Contains the Port Gasket supporting logic and resources like the User Clock block to provide the logic joining the AFU to the rest of the FIM.
      - Protocol Checker (***src/common/protocol\_checker***): PCIe protocol checking is done by this logic to prevent fatal and catastrophic errors from occurring between the host, PCIe IP core on the FPGA, and the FIM logic.
      - Remote SignalTap Protocol (STP) (***src/common/remote\_stop***): FPGA on-chip debugging is enable with this logic which implements the foundation required to implement a remotely-accessible SignalTap instance in the FIM.
      - Streaming-to-Memory-Mapped Bus Translation (***src/common/st2mm***): This directory contains the code required to convert the high-level AXI Streaming bus from the PCIe Subsystem to an AXI4-Lite memory-mapped bus and back again.
      - Time-of-Day (ToD) Timing Synchronization Logic (***src/common/tod***): IP and top-level Platform Designer/Qsys files are located in this directory for the ToD implementation in the FIM.
#### FPGA Device Family-Specific Source Code (***src/fpga\_family***)
   - Contains the scripts, source code, and IP that is specific to an FPGA device family, but not necessarity to any specific board or implementation.
   - Currently, this repository contains specific support for the following FPGA device families:
      - Intel Stratix 10
      - Intel Agilex
   - Please examine the directory trees to see a list of the device-specific blocks that are available for use in the FIM design.
