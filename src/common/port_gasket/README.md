# Port Gasket

The port gasket maps devices to AFU instances. The implementation here passes
all devices to a single afu\_main\(\) module. The afu\_main\(\) module holds the
root of AFU-specific code.

Two implementations of afu\_main\(\) are present here. Only one should be
instantiated in a design:

* [afu\_main\_std\_exerciser/afu\_main.sv](afu_main_std_exerciser/afu_main.sv) is the
  default design. It connects exercisers directly to the FIM's device interfaces.
  AFU's connecting in this manner are platform-specific, since the ports passed to
  afu\_main\(\) may vary by platform.

* [afu\_main\_pim/afu\_main.sv](afu_main_pim/afu_main.sv) maps the FIM's device
  interfaces to the
  [Platform Interface Manager \(PIM\)](https://github.com/OPAE/ofs-platform-afu-bbb).
  The PIM-based afu\_main\(\) can then be configured to instantiate user-provided
  AFU's that connect to the PIM. The PIM offers memory-mapped PCIe DMA and MMIO
  interfaces, AXI and Avalon protocol transformations for local memory, reorder
  buffers and clock crossings.
