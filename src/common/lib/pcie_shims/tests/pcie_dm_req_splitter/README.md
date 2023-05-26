# PCIe Data Mover Request Splitter Test

This HW/SW pair tests the [large request splitter](../../pcie_dm_req_splitter/). The test can be loaded in ASE or run on hardware using standard methods for PR loadable AFUs. The [afu\_main.sv](hw/rtl/afu_main.sv) and [port_afu_instances.sv](hw/rtl/port\_afu\_instances.sv) modules might require platform-specific modifications to compile.

The software, [pcie\_dm\_req\_splitter.c](sw/pcie_dm_req_splitter.c) maps 2MB read and write buffers, filling the read buffer with random data. Commands are sent to trigger DM read requests with random start addresses and lengths. Read lengths may span multiple 4KB pages. Both the request splitter and completion merger are instantiated. The test should break the large requests into multiple small reads and recombine their completions into a single packet. Both the software and hardware sides of the test compute hashes. The hardware hashes the full width of the data bus and the software computes the expected value. The test aborts on a hash mismatch.

The software may also enable loopback mode in which completions are turned into a large write request, which will also be split.

In simulation, log files are generated with TLP streams before and after transformation by the test itself and by the request splitter and merger modules.
