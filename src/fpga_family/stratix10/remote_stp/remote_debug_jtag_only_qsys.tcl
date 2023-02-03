package require -exact qsys 20.4

# create the system "remote_debug_jtag_only"
proc do_create_remote_debug_jtag_only {} {
	# create the system
	create_system remote_debug_jtag_only
	set_project_property DEVICE {AGFB014R24A2E2VR0}
	set_project_property DEVICE_FAMILY {Agilex}
	set_project_property HIDE_FROM_IP_CATALOG {false}
	set_use_testbench_naming_pattern 0 {}

	# add HDL parameters

	# add the components
	add_component clock_in ip/remote_debug_jtag_only/remote_debug_jtag_only_clock_in.ip altera_clock_bridge clock_in 19.2.0
	load_component clock_in
	set_component_parameter_value EXPLICIT_CLOCK_RATE {100000000.0}
	set_component_parameter_value NUM_CLOCK_OUTPUTS {1}
	set_component_project_property HIDE_FROM_IP_CATALOG {false}
	save_component
	load_instantiation clock_in
	remove_instantiation_interfaces_and_ports
	add_instantiation_interface in_clk clock INPUT
	set_instantiation_interface_parameter_value in_clk clockRate {0}
	set_instantiation_interface_parameter_value in_clk externallyDriven {false}
	set_instantiation_interface_parameter_value in_clk ptfSchematicName {}
	add_instantiation_interface_port in_clk in_clk clk 1 STD_LOGIC Input
	add_instantiation_interface out_clk clock OUTPUT
	set_instantiation_interface_parameter_value out_clk associatedDirectClock {in_clk}
	set_instantiation_interface_parameter_value out_clk clockRate {100000000}
	set_instantiation_interface_parameter_value out_clk clockRateKnown {true}
	set_instantiation_interface_parameter_value out_clk externallyDriven {false}
	set_instantiation_interface_parameter_value out_clk ptfSchematicName {}
	set_instantiation_interface_sysinfo_parameter_value out_clk clock_rate {100000000}
	add_instantiation_interface_port out_clk out_clk clk 1 STD_LOGIC Output
	save_instantiation
	add_component host_if ip/remote_debug_jtag_only/host_if.ip altera_axi_bridge host_if 19.2.1
	load_component host_if
	set_component_parameter_value ACE_LITE_SUPPORT {0}
	set_component_parameter_value ADDR_WIDTH {17}
	set_component_parameter_value AXI_VERSION {AXI4}
	set_component_parameter_value COMBINED_ACCEPTANCE_CAPABILITY {16}
	set_component_parameter_value COMBINED_ISSUING_CAPABILITY {16}
	set_component_parameter_value DATA_WIDTH {64}
	set_component_parameter_value M0_ID_WIDTH {8}
	set_component_parameter_value READ_ACCEPTANCE_CAPABILITY {16}
	set_component_parameter_value READ_ADDR_USER_WIDTH {64}
	set_component_parameter_value READ_DATA_REORDERING_DEPTH {1}
	set_component_parameter_value READ_DATA_USER_WIDTH {64}
	set_component_parameter_value READ_ISSUING_CAPABILITY {16}
	set_component_parameter_value S0_ID_WIDTH {8}
	set_component_parameter_value SYNC_RESET {0}
	set_component_parameter_value USE_M0_ARBURST {1}
	set_component_parameter_value USE_M0_ARCACHE {1}
	set_component_parameter_value USE_M0_ARID {1}
	set_component_parameter_value USE_M0_ARLEN {1}
	set_component_parameter_value USE_M0_ARLOCK {1}
	set_component_parameter_value USE_M0_ARQOS {1}
	set_component_parameter_value USE_M0_ARREGION {1}
	set_component_parameter_value USE_M0_ARSIZE {1}
	set_component_parameter_value USE_M0_ARUSER {0}
	set_component_parameter_value USE_M0_AWBURST {1}
	set_component_parameter_value USE_M0_AWCACHE {1}
	set_component_parameter_value USE_M0_AWID {1}
	set_component_parameter_value USE_M0_AWLEN {1}
	set_component_parameter_value USE_M0_AWLOCK {0}
	set_component_parameter_value USE_M0_AWQOS {1}
	set_component_parameter_value USE_M0_AWREGION {1}
	set_component_parameter_value USE_M0_AWSIZE {1}
	set_component_parameter_value USE_M0_AWUSER {0}
	set_component_parameter_value USE_M0_BID {1}
	set_component_parameter_value USE_M0_BRESP {1}
	set_component_parameter_value USE_M0_BUSER {0}
	set_component_parameter_value USE_M0_RID {1}
	set_component_parameter_value USE_M0_RLAST {1}
	set_component_parameter_value USE_M0_RRESP {1}
	set_component_parameter_value USE_M0_RUSER {0}
	set_component_parameter_value USE_M0_WSTRB {1}
	set_component_parameter_value USE_M0_WUSER {0}
	set_component_parameter_value USE_PIPELINE {1}
	set_component_parameter_value USE_S0_ARCACHE {1}
	set_component_parameter_value USE_S0_ARLOCK {1}
	set_component_parameter_value USE_S0_ARPROT {1}
	set_component_parameter_value USE_S0_ARQOS {1}
	set_component_parameter_value USE_S0_ARREGION {1}
	set_component_parameter_value USE_S0_ARUSER {0}
	set_component_parameter_value USE_S0_AWCACHE {1}
	set_component_parameter_value USE_S0_AWLOCK {0}
	set_component_parameter_value USE_S0_AWPROT {1}
	set_component_parameter_value USE_S0_AWQOS {1}
	set_component_parameter_value USE_S0_AWREGION {1}
	set_component_parameter_value USE_S0_AWUSER {0}
	set_component_parameter_value USE_S0_BRESP {1}
	set_component_parameter_value USE_S0_BUSER {0}
	set_component_parameter_value USE_S0_RRESP {1}
	set_component_parameter_value USE_S0_RUSER {0}
	set_component_parameter_value USE_S0_WLAST {1}
	set_component_parameter_value USE_S0_WUSER {0}
	set_component_parameter_value WRITE_ACCEPTANCE_CAPABILITY {16}
	set_component_parameter_value WRITE_ADDR_USER_WIDTH {64}
	set_component_parameter_value WRITE_DATA_USER_WIDTH {64}
	set_component_parameter_value WRITE_ISSUING_CAPABILITY {16}
	set_component_parameter_value WRITE_RESP_USER_WIDTH {64}
	set_component_project_property HIDE_FROM_IP_CATALOG {false}
	save_component
	load_instantiation host_if
	remove_instantiation_interfaces_and_ports
	set_instantiation_assignment_value embeddedsw.dts.compatible {simple-bus}
	set_instantiation_assignment_value embeddedsw.dts.group {bridge}
	set_instantiation_assignment_value embeddedsw.dts.name {bridge}
	set_instantiation_assignment_value embeddedsw.dts.vendor {altr}
	add_instantiation_interface clk clock INPUT
	set_instantiation_interface_parameter_value clk clockRate {0}
	set_instantiation_interface_parameter_value clk externallyDriven {false}
	set_instantiation_interface_parameter_value clk ptfSchematicName {}
	add_instantiation_interface_port clk aclk clk 1 STD_LOGIC Input
	add_instantiation_interface clk_reset reset INPUT
	set_instantiation_interface_parameter_value clk_reset associatedClock {clk}
	set_instantiation_interface_parameter_value clk_reset synchronousEdges {DEASSERT}
	add_instantiation_interface_port clk_reset aresetn reset_n 1 STD_LOGIC Input
	add_instantiation_interface s0 axi4 INPUT
	set_instantiation_interface_parameter_value s0 associatedClock {clk}
	set_instantiation_interface_parameter_value s0 associatedReset {clk_reset}
	set_instantiation_interface_parameter_value s0 bridgesToMaster {m0}
	set_instantiation_interface_parameter_value s0 combinedAcceptanceCapability {16}
	set_instantiation_interface_parameter_value s0 maximumOutstandingReads {1}
	set_instantiation_interface_parameter_value s0 maximumOutstandingTransactions {1}
	set_instantiation_interface_parameter_value s0 maximumOutstandingWrites {1}
	set_instantiation_interface_parameter_value s0 readAcceptanceCapability {16}
	set_instantiation_interface_parameter_value s0 readDataReorderingDepth {1}
	set_instantiation_interface_parameter_value s0 trustzoneAware {true}
	set_instantiation_interface_parameter_value s0 writeAcceptanceCapability {16}
	set_instantiation_interface_sysinfo_parameter_value s0 address_map {}
	set_instantiation_interface_sysinfo_parameter_value s0 address_width {}
	set_instantiation_interface_sysinfo_parameter_value s0 max_slave_data_width {}
	add_instantiation_interface_port s0 s0_awid awid 8 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_awaddr awaddr 17 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_awlen awlen 8 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_awsize awsize 3 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_awburst awburst 2 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_awcache awcache 4 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_awprot awprot 3 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_awqos awqos 4 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_awregion awregion 4 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_awvalid awvalid 1 STD_LOGIC Input
	add_instantiation_interface_port s0 s0_awready awready 1 STD_LOGIC Output
	add_instantiation_interface_port s0 s0_wdata wdata 64 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_wstrb wstrb 8 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_wlast wlast 1 STD_LOGIC Input
	add_instantiation_interface_port s0 s0_wvalid wvalid 1 STD_LOGIC Input
	add_instantiation_interface_port s0 s0_wready wready 1 STD_LOGIC Output
	add_instantiation_interface_port s0 s0_bid bid 8 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port s0 s0_bresp bresp 2 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port s0 s0_bvalid bvalid 1 STD_LOGIC Output
	add_instantiation_interface_port s0 s0_bready bready 1 STD_LOGIC Input
	add_instantiation_interface_port s0 s0_arid arid 8 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_araddr araddr 17 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_arlen arlen 8 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_arsize arsize 3 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_arburst arburst 2 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_arlock arlock 1 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_arcache arcache 4 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_arprot arprot 3 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_arqos arqos 4 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_arregion arregion 4 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port s0 s0_arvalid arvalid 1 STD_LOGIC Input
	add_instantiation_interface_port s0 s0_arready arready 1 STD_LOGIC Output
	add_instantiation_interface_port s0 s0_rid rid 8 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port s0 s0_rdata rdata 64 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port s0 s0_rresp rresp 2 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port s0 s0_rlast rlast 1 STD_LOGIC Output
	add_instantiation_interface_port s0 s0_rvalid rvalid 1 STD_LOGIC Output
	add_instantiation_interface_port s0 s0_rready rready 1 STD_LOGIC Input
	add_instantiation_interface m0 axi4 OUTPUT
	set_instantiation_interface_parameter_value m0 associatedClock {clk}
	set_instantiation_interface_parameter_value m0 associatedReset {clk_reset}
	set_instantiation_interface_parameter_value m0 combinedIssuingCapability {16}
	set_instantiation_interface_parameter_value m0 issuesFIXEDBursts {true}
	set_instantiation_interface_parameter_value m0 issuesINCRBursts {true}
	set_instantiation_interface_parameter_value m0 issuesWRAPBursts {true}
	set_instantiation_interface_parameter_value m0 maximumOutstandingReads {1}
	set_instantiation_interface_parameter_value m0 maximumOutstandingTransactions {1}
	set_instantiation_interface_parameter_value m0 maximumOutstandingWrites {1}
	set_instantiation_interface_parameter_value m0 readIssuingCapability {16}
	set_instantiation_interface_parameter_value m0 trustzoneAware {true}
	set_instantiation_interface_parameter_value m0 writeIssuingCapability {16}
	add_instantiation_interface_port m0 m0_awid awid 8 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_awaddr awaddr 17 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_awlen awlen 8 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_awsize awsize 3 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_awburst awburst 2 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_awcache awcache 4 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_awprot awprot 3 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_awqos awqos 4 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_awregion awregion 4 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_awvalid awvalid 1 STD_LOGIC Output
	add_instantiation_interface_port m0 m0_awready awready 1 STD_LOGIC Input
	add_instantiation_interface_port m0 m0_wdata wdata 64 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_wstrb wstrb 8 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_wlast wlast 1 STD_LOGIC Output
	add_instantiation_interface_port m0 m0_wvalid wvalid 1 STD_LOGIC Output
	add_instantiation_interface_port m0 m0_wready wready 1 STD_LOGIC Input
	add_instantiation_interface_port m0 m0_bid bid 8 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port m0 m0_bresp bresp 2 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port m0 m0_bvalid bvalid 1 STD_LOGIC Input
	add_instantiation_interface_port m0 m0_bready bready 1 STD_LOGIC Output
	add_instantiation_interface_port m0 m0_arid arid 8 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_araddr araddr 17 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_arlen arlen 8 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_arsize arsize 3 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_arburst arburst 2 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_arlock arlock 1 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_arcache arcache 4 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_arprot arprot 3 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_arqos arqos 4 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_arregion arregion 4 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port m0 m0_arvalid arvalid 1 STD_LOGIC Output
	add_instantiation_interface_port m0 m0_arready arready 1 STD_LOGIC Input
	add_instantiation_interface_port m0 m0_rid rid 8 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port m0 m0_rdata rdata 64 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port m0 m0_rresp rresp 2 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port m0 m0_rlast rlast 1 STD_LOGIC Input
	add_instantiation_interface_port m0 m0_rvalid rvalid 1 STD_LOGIC Input
	add_instantiation_interface_port m0 m0_rready rready 1 STD_LOGIC Output
	save_instantiation
	add_component jop_blaster ip/remote_debug_jtag_only/jop_blaster.ip intel_jop_blaster jop_blaster 1.0.0
	load_component jop_blaster
	set_component_parameter_value EXPORT_SLD_ED {1}
	set_component_parameter_value MEM_SIZE {4096}
	set_component_parameter_value MEM_WIDTH {64}
	set_component_parameter_value USE_TCK_ENA {1}
	set_component_project_property HIDE_FROM_IP_CATALOG {false}
	save_component
	load_instantiation jop_blaster
	remove_instantiation_interfaces_and_ports
	add_instantiation_interface clk clock INPUT
	set_instantiation_interface_parameter_value clk clockRate {0}
	set_instantiation_interface_parameter_value clk externallyDriven {false}
	set_instantiation_interface_parameter_value clk ptfSchematicName {}
	add_instantiation_interface_port clk clk_clk clk 1 STD_LOGIC Input
	add_instantiation_interface reset reset INPUT
	set_instantiation_interface_parameter_value reset associatedClock {clk}
	set_instantiation_interface_parameter_value reset synchronousEdges {DEASSERT}
	add_instantiation_interface_port reset reset_reset reset 1 STD_LOGIC Input
	add_instantiation_interface jtag_clock clock OUTPUT
	set_instantiation_interface_parameter_value jtag_clock associatedDirectClock {}
	set_instantiation_interface_parameter_value jtag_clock clockRate {0}
	set_instantiation_interface_parameter_value jtag_clock clockRateKnown {false}
	set_instantiation_interface_parameter_value jtag_clock externallyDriven {false}
	set_instantiation_interface_parameter_value jtag_clock ptfSchematicName {}
	set_instantiation_interface_sysinfo_parameter_value jtag_clock clock_rate {0}
	add_instantiation_interface_port jtag_clock jtag_clock_clk clk 1 STD_LOGIC Output
	add_instantiation_interface jtag_signals conduit INPUT
	set_instantiation_interface_parameter_value jtag_signals associatedClock {jtag_clock}
	set_instantiation_interface_parameter_value jtag_signals associatedReset {}
	set_instantiation_interface_parameter_value jtag_signals prSafe {false}
	add_instantiation_interface_port jtag_signals jtag_signals_tck_ena tck_ena 1 STD_LOGIC Output
	add_instantiation_interface_port jtag_signals jtag_signals_tms tms 1 STD_LOGIC Output
	add_instantiation_interface_port jtag_signals jtag_signals_tdi tdi 1 STD_LOGIC Output
	add_instantiation_interface_port jtag_signals jtag_signals_tdo tdo 1 STD_LOGIC Input
	add_instantiation_interface avmm_s avalon INPUT
	set_instantiation_interface_parameter_value avmm_s addressAlignment {DYNAMIC}
	set_instantiation_interface_parameter_value avmm_s addressGroup {0}
	set_instantiation_interface_parameter_value avmm_s addressSpan {16384}
	set_instantiation_interface_parameter_value avmm_s addressUnits {SYMBOLS}
	set_instantiation_interface_parameter_value avmm_s alwaysBurstMaxBurst {false}
	set_instantiation_interface_parameter_value avmm_s associatedClock {clk}
	set_instantiation_interface_parameter_value avmm_s associatedReset {reset}
	set_instantiation_interface_parameter_value avmm_s bitsPerSymbol {8}
	set_instantiation_interface_parameter_value avmm_s bridgedAddressOffset {0}
	set_instantiation_interface_parameter_value avmm_s bridgesToMaster {}
	set_instantiation_interface_parameter_value avmm_s burstOnBurstBoundariesOnly {false}
	set_instantiation_interface_parameter_value avmm_s burstcountUnits {WORDS}
	set_instantiation_interface_parameter_value avmm_s constantBurstBehavior {false}
	set_instantiation_interface_parameter_value avmm_s explicitAddressSpan {0}
	set_instantiation_interface_parameter_value avmm_s holdTime {0}
	set_instantiation_interface_parameter_value avmm_s interleaveBursts {false}
	set_instantiation_interface_parameter_value avmm_s isBigEndian {false}
	set_instantiation_interface_parameter_value avmm_s isFlash {false}
	set_instantiation_interface_parameter_value avmm_s isMemoryDevice {false}
	set_instantiation_interface_parameter_value avmm_s isNonVolatileStorage {false}
	set_instantiation_interface_parameter_value avmm_s linewrapBursts {false}
	set_instantiation_interface_parameter_value avmm_s maximumPendingReadTransactions {1}
	set_instantiation_interface_parameter_value avmm_s maximumPendingWriteTransactions {0}
	set_instantiation_interface_parameter_value avmm_s minimumReadLatency {1}
	set_instantiation_interface_parameter_value avmm_s minimumResponseLatency {1}
	set_instantiation_interface_parameter_value avmm_s minimumUninterruptedRunLength {1}
	set_instantiation_interface_parameter_value avmm_s prSafe {false}
	set_instantiation_interface_parameter_value avmm_s printableDevice {false}
	set_instantiation_interface_parameter_value avmm_s readLatency {0}
	set_instantiation_interface_parameter_value avmm_s readWaitStates {1}
	set_instantiation_interface_parameter_value avmm_s readWaitTime {1}
	set_instantiation_interface_parameter_value avmm_s registerIncomingSignals {false}
	set_instantiation_interface_parameter_value avmm_s registerOutgoingSignals {false}
	set_instantiation_interface_parameter_value avmm_s setupTime {0}
	set_instantiation_interface_parameter_value avmm_s timingUnits {Cycles}
	set_instantiation_interface_parameter_value avmm_s transparentBridge {false}
	set_instantiation_interface_parameter_value avmm_s waitrequestAllowance {0}
	set_instantiation_interface_parameter_value avmm_s wellBehavedWaitrequest {false}
	set_instantiation_interface_parameter_value avmm_s writeLatency {0}
	set_instantiation_interface_parameter_value avmm_s writeWaitStates {0}
	set_instantiation_interface_parameter_value avmm_s writeWaitTime {0}
	set_instantiation_interface_assignment_value avmm_s embeddedsw.configuration.isFlash {0}
	set_instantiation_interface_assignment_value avmm_s embeddedsw.configuration.isMemoryDevice {0}
	set_instantiation_interface_assignment_value avmm_s embeddedsw.configuration.isNonVolatileStorage {0}
	set_instantiation_interface_assignment_value avmm_s embeddedsw.configuration.isPrintableDevice {0}
	set_instantiation_interface_sysinfo_parameter_value avmm_s address_map {<address-map><slave name='avmm_s' start='0x0' end='0x4000' datawidth='64' /></address-map>}
	set_instantiation_interface_sysinfo_parameter_value avmm_s address_width {14}
	set_instantiation_interface_sysinfo_parameter_value avmm_s max_slave_data_width {64}
	add_instantiation_interface_port avmm_s avmm_s_waitrequest waitrequest 1 STD_LOGIC Output
	add_instantiation_interface_port avmm_s avmm_s_readdata readdata 64 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port avmm_s avmm_s_readdatavalid readdatavalid 1 STD_LOGIC Output
	add_instantiation_interface_port avmm_s avmm_s_burstcount burstcount 1 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port avmm_s avmm_s_writedata writedata 64 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port avmm_s avmm_s_address address 14 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port avmm_s avmm_s_write write 1 STD_LOGIC Input
	add_instantiation_interface_port avmm_s avmm_s_read read 1 STD_LOGIC Input
	add_instantiation_interface_port avmm_s avmm_s_byteenable byteenable 8 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port avmm_s avmm_s_debugaccess debugaccess 1 STD_LOGIC Input
	save_instantiation
	add_component reset_in ip/remote_debug_jtag_only/remote_debug_jtag_only_reset_in.ip altera_reset_bridge reset_in 19.2.0
	load_component reset_in
	set_component_parameter_value ACTIVE_LOW_RESET {1}
	set_component_parameter_value NUM_RESET_OUTPUTS {1}
	set_component_parameter_value SYNCHRONOUS_EDGES {deassert}
	set_component_parameter_value SYNC_RESET {0}
	set_component_parameter_value USE_RESET_REQUEST {0}
	set_component_project_property HIDE_FROM_IP_CATALOG {false}
	save_component
	load_instantiation reset_in
	remove_instantiation_interfaces_and_ports
	add_instantiation_interface clk clock INPUT
	set_instantiation_interface_parameter_value clk clockRate {0}
	set_instantiation_interface_parameter_value clk externallyDriven {false}
	set_instantiation_interface_parameter_value clk ptfSchematicName {}
	add_instantiation_interface_port clk clk clk 1 STD_LOGIC Input
	add_instantiation_interface in_reset reset INPUT
	set_instantiation_interface_parameter_value in_reset associatedClock {clk}
	set_instantiation_interface_parameter_value in_reset synchronousEdges {DEASSERT}
	add_instantiation_interface_port in_reset in_reset_n reset_n 1 STD_LOGIC Input
	add_instantiation_interface out_reset reset OUTPUT
	set_instantiation_interface_parameter_value out_reset associatedClock {clk}
	set_instantiation_interface_parameter_value out_reset associatedDirectReset {in_reset}
	set_instantiation_interface_parameter_value out_reset associatedResetSinks {in_reset}
	set_instantiation_interface_parameter_value out_reset synchronousEdges {DEASSERT}
	add_instantiation_interface_port out_reset out_reset_n reset_n 1 STD_LOGIC Output
	save_instantiation
	add_component sys_clk ip/remote_debug_jtag_only/sys_clk.ip altera_clock_bridge sys_clk 19.2.0
	load_component sys_clk
	set_component_parameter_value EXPLICIT_CLOCK_RATE {250000000.0}
	set_component_parameter_value NUM_CLOCK_OUTPUTS {1}
	set_component_project_property HIDE_FROM_IP_CATALOG {false}
	save_component
	load_instantiation sys_clk
	remove_instantiation_interfaces_and_ports
	add_instantiation_interface in_clk clock INPUT
	set_instantiation_interface_parameter_value in_clk clockRate {0}
	set_instantiation_interface_parameter_value in_clk externallyDriven {false}
	set_instantiation_interface_parameter_value in_clk ptfSchematicName {}
	add_instantiation_interface_port in_clk in_clk clk 1 STD_LOGIC Input
	add_instantiation_interface out_clk clock OUTPUT
	set_instantiation_interface_parameter_value out_clk associatedDirectClock {in_clk}
	set_instantiation_interface_parameter_value out_clk clockRate {250000000}
	set_instantiation_interface_parameter_value out_clk clockRateKnown {true}
	set_instantiation_interface_parameter_value out_clk externallyDriven {false}
	set_instantiation_interface_parameter_value out_clk ptfSchematicName {}
	set_instantiation_interface_sysinfo_parameter_value out_clk clock_rate {250000000}
	add_instantiation_interface_port out_clk out_clk clk 1 STD_LOGIC Output
	save_instantiation

	# add wirelevel expressions

	# add the connections
	add_connection clock_in.out_clk/jop_blaster.clk
	set_connection_parameter_value clock_in.out_clk/jop_blaster.clk clockDomainSysInfo {1}
	set_connection_parameter_value clock_in.out_clk/jop_blaster.clk clockRateSysInfo {100000000.0}
	set_connection_parameter_value clock_in.out_clk/jop_blaster.clk clockResetSysInfo {}
	set_connection_parameter_value clock_in.out_clk/jop_blaster.clk resetDomainSysInfo {1}
	add_connection host_if.m0/jop_blaster.avmm_s
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s addressMapSysInfo {}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s addressWidthSysInfo {}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s arbitrationPriority {1}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s baseAddress {0x4000}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s defaultConnection {0}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s domainAlias {}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s qsys_mm.burstAdapterImplementation {GENERIC_CONVERTER}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s qsys_mm.clockCrossingAdapter {HANDSHAKE}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s qsys_mm.enableAllPipelines {FALSE}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s qsys_mm.enableEccProtection {FALSE}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s qsys_mm.enableInstrumentation {FALSE}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s qsys_mm.insertDefaultSlave {FALSE}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s qsys_mm.interconnectResetSource {DEFAULT}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s qsys_mm.interconnectType {STANDARD}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s qsys_mm.maxAdditionalLatency {1}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s qsys_mm.optimizeRdFifoSize {FALSE}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s qsys_mm.piplineType {PIPELINE_STAGE}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s qsys_mm.syncResets {TRUE}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s qsys_mm.widthAdapterImplementation {GENERIC_CONVERTER}
	set_connection_parameter_value host_if.m0/jop_blaster.avmm_s slaveDataWidthSysInfo {-1}
	add_connection reset_in.out_reset/host_if.clk_reset
	set_connection_parameter_value reset_in.out_reset/host_if.clk_reset clockDomainSysInfo {3}
	set_connection_parameter_value reset_in.out_reset/host_if.clk_reset clockResetSysInfo {}
	set_connection_parameter_value reset_in.out_reset/host_if.clk_reset resetDomainSysInfo {3}
	add_connection reset_in.out_reset/jop_blaster.reset
	set_connection_parameter_value reset_in.out_reset/jop_blaster.reset clockDomainSysInfo {3}
	set_connection_parameter_value reset_in.out_reset/jop_blaster.reset clockResetSysInfo {}
	set_connection_parameter_value reset_in.out_reset/jop_blaster.reset resetDomainSysInfo {3}
	add_connection sys_clk.out_clk/host_if.clk
	set_connection_parameter_value sys_clk.out_clk/host_if.clk clockDomainSysInfo {2}
	set_connection_parameter_value sys_clk.out_clk/host_if.clk clockRateSysInfo {250000000.0}
	set_connection_parameter_value sys_clk.out_clk/host_if.clk clockResetSysInfo {}
	set_connection_parameter_value sys_clk.out_clk/host_if.clk resetDomainSysInfo {2}
	add_connection sys_clk.out_clk/reset_in.clk
	set_connection_parameter_value sys_clk.out_clk/reset_in.clk clockDomainSysInfo {2}
	set_connection_parameter_value sys_clk.out_clk/reset_in.clk clockRateSysInfo {250000000.0}
	set_connection_parameter_value sys_clk.out_clk/reset_in.clk clockResetSysInfo {}
	set_connection_parameter_value sys_clk.out_clk/reset_in.clk resetDomainSysInfo {2}

	# add the exports
	set_interface_property jtag_clk EXPORT_OF clock_in.in_clk
	set_interface_property host_if_slave EXPORT_OF host_if.s0
	set_interface_property jtag_tck EXPORT_OF jop_blaster.jtag_clock
	set_interface_property jtag EXPORT_OF jop_blaster.jtag_signals
	set_interface_property axi_reset_n EXPORT_OF reset_in.in_reset
	set_interface_property axi_clk EXPORT_OF sys_clk.in_clk

	# set values for exposed HDL parameters
	set_domain_assignment host_if.m0 qsys_mm.burstAdapterImplementation GENERIC_CONVERTER
	set_domain_assignment host_if.m0 qsys_mm.clockCrossingAdapter HANDSHAKE
	set_domain_assignment host_if.m0 qsys_mm.enableAllPipelines FALSE
	set_domain_assignment host_if.m0 qsys_mm.enableEccProtection FALSE
	set_domain_assignment host_if.m0 qsys_mm.enableInstrumentation FALSE
	set_domain_assignment host_if.m0 qsys_mm.insertDefaultSlave FALSE
	set_domain_assignment host_if.m0 qsys_mm.interconnectResetSource DEFAULT
	set_domain_assignment host_if.m0 qsys_mm.interconnectType STANDARD
	set_domain_assignment host_if.m0 qsys_mm.maxAdditionalLatency 1
	set_domain_assignment host_if.m0 qsys_mm.optimizeRdFifoSize FALSE
	set_domain_assignment host_if.m0 qsys_mm.piplineType PIPELINE_STAGE
	set_domain_assignment host_if.m0 qsys_mm.syncResets TRUE
	set_domain_assignment host_if.m0 qsys_mm.widthAdapterImplementation GENERIC_CONVERTER

	# set the the module properties
	set_module_property BONUS_DATA {<?xml version="1.0" encoding="UTF-8"?>
<bonusData>
 <element __value="clock_in">
  <datum __value="_sortIndex" value="1" type="int" />
 </element>
 <element __value="host_if">
  <datum __value="_sortIndex" value="3" type="int" />
 </element>
 <element __value="jop_blaster">
  <datum __value="_sortIndex" value="4" type="int" />
 </element>
 <element __value="jop_blaster.avmm_s">
  <datum __value="baseAddress" value="16384" type="String" />
 </element>
 <element __value="reset_in">
  <datum __value="_sortIndex" value="2" type="int" />
 </element>
 <element __value="sys_clk">
  <datum __value="_sortIndex" value="0" type="int" />
 </element>
</bonusData>
}
	set_module_property FILE {remote_debug_jtag_only.qsys}
	set_module_property GENERATION_ID {0x00000000}
	set_module_property NAME {remote_debug_jtag_only}

	# save the system
	sync_sysinfo_parameters
	save_system remote_debug_jtag_only
}

proc do_set_exported_interface_sysinfo_parameters {} {
}

# create all the systems, from bottom up
do_create_remote_debug_jtag_only

# set system info parameters on exported interface, from bottom up
do_set_exported_interface_sysinfo_parameters
