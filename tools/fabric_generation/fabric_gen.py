#!/usr/bin/env python3
# Copyright (C) 2022-2023 Intel Corporation
# SPDX-License-Identifier: MIT

"""
Script to generate fabric tcl files

input: <fabric connection>.txt file
Run Command "python3 fabric_gen.py --cfg <fabric configuration file> --fabric apf --tcl <output tcl file name>"
#>> python3 fabric_gen.py --cfg apf.txt --fabric apf --tcl apf_test.tcl
>> python3 fabric_gen.py --cfg feature_config.yml --fabric_def apf.txt --fabric_name apf --tcl apf.tcl

"""

import abc
import argparse
import logging
import logging.handlers
import yaml

class Register:
    def __init__(self, name, base_addr, addr_width, fabric):
        self.name = name
        self.base_addr = base_addr
        self.addr_width = addr_width
        self.fabric = fabric

    @abc.abstractmethod
    def inst_if(self):
        #raise NotImplementedError()
        pass


class MasterReg(Register):
    #def __init__(self, name, reg_type, base_addr, addr_width, fabric, slaves, enabled_ports):
    def __init__(self, name, reg_type, base_addr, addr_width, fabric, slaves):
        self.reg_type = 'mst'
        all_slaves = slaves.split(',')
        #self.slaves = all_slaves
        #self.slaves = self.enable_slaves_by_feature(enabled_ports, all_slaves)
        self.slaves = self.enable_slaves_by_feature(all_slaves)
        super(MasterReg, self).__init__(name, base_addr, addr_width, fabric)

    #def enable_slaves_by_feature(self, enabled_ports, all_slaves):
    def enable_slaves_by_feature(self, all_slaves):
        result = []
        for slave in all_slaves:
           # if slave in enabled_ports:
             result.append(slave)

        return result  

    def show_slaves(self):
        print(f'{self.name} has the following slaves:')
        for slave in self.slaves:
            print(f'{slave}')

    def inst_if(self):
        dev = self.name 
        fab = self.fabric
        aw = self.addr_width
        cap = 16
        content = []
        content.append(f'''
        add_component {fab}_{dev}_mst ip/{fab}/{fab}_{dev}_mst.ip axi4lite_shim {fab}_{dev}_mst 1.0
        load_component {fab}_{dev}_mst
        set_component_parameter_value AW {{{aw}}}
        set_component_parameter_value DW {{64}}
        set_component_project_property HIDE_FROM_IP_CATALOG {{false}}
        save_component
        load_instantiation {fab}_{dev}_mst
        remove_instantiation_interfaces_and_ports
        add_instantiation_interface clock clock INPUT
        set_instantiation_interface_parameter_value clock clockRate {{0}}
        set_instantiation_interface_parameter_value clock externallyDriven {{false}}
        set_instantiation_interface_parameter_value clock ptfSchematicName {{}}
        add_instantiation_interface_port clock clk clk 1 STD_LOGIC Input
        add_instantiation_interface reset reset INPUT
        set_instantiation_interface_parameter_value reset associatedClock {{clock}}
        set_instantiation_interface_parameter_value reset synchronousEdges {{DEASSERT}}
        add_instantiation_interface_port reset rst_n reset_n 1 STD_LOGIC Input
        add_instantiation_interface altera_axi4lite_slave axi4lite INPUT
        set_instantiation_interface_parameter_value altera_axi4lite_slave associatedClock {{clock}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave associatedReset {{reset}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave bridgesToMaster {{}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave combinedAcceptanceCapability {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingReads {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingTransactions {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingWrites {{{cap}/4}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave readAcceptanceCapability {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave writeAcceptanceCapability {{{cap}/4}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave readDataReorderingDepth {{1}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave trustzoneAware {{true}}
        add_instantiation_interface_port altera_axi4lite_slave s_awaddr awaddr {aw} STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_awprot awprot 3 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_awvalid awvalid 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_slave s_awready awready 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_wdata wdata 64 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_wstrb wstrb 8 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_wvalid wvalid 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_slave s_wready wready 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_bresp bresp 2 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_slave s_bvalid bvalid 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_bready bready 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_slave s_araddr araddr {aw} STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_arprot arprot 3 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_arvalid arvalid 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_slave s_arready arready 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_rdata rdata 64 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_slave s_rresp rresp 2 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_slave s_rvalid rvalid 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_rready rready 1 STD_LOGIC Input
        add_instantiation_interface altera_axi4lite_master axi4lite OUTPUT
        set_instantiation_interface_parameter_value altera_axi4lite_master associatedClock {{clock}}
        set_instantiation_interface_parameter_value altera_axi4lite_master associatedReset {{reset}}
        set_instantiation_interface_parameter_value altera_axi4lite_master combinedIssuingCapability {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_master maximumOutstandingReads {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_master maximumOutstandingTransactions {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_master maximumOutstandingWrites {{{cap}/4}}
        set_instantiation_interface_parameter_value altera_axi4lite_master readIssuingCapability {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_master trustzoneAware {{true}}
        set_instantiation_interface_parameter_value altera_axi4lite_master writeIssuingCapability {{{cap}/4}}
        add_instantiation_interface_port altera_axi4lite_master m_awaddr awaddr {aw} STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_master m_awprot awprot 3 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_master m_awvalid awvalid 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_master m_awready awready 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_master m_wdata wdata 64 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_master m_wstrb wstrb 8 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_master m_wvalid wvalid 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_master m_wready wready 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_master m_bresp bresp 2 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_master m_bvalid bvalid 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_master m_bready bready 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_master m_araddr araddr {aw} STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_master m_arprot arprot 3 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_master m_arvalid arvalid 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_master m_arready arready 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_master m_rdata rdata 64 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_master m_rresp rresp 2 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_master m_rvalid rvalid 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_master m_rready rready 1 STD_LOGIC Output
        save_instantiation
        ''')

        with open(args.tcl, 'a') as fOut:
            fOut.write('\n'.join(content))
        
    def conn_dev_clkrst(self):
        dev = self.name
        fab = self.fabric
        itf = self.reg_type 
        content = []
        content.append(f'''
        add_connection {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock
        set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock clockDomainSysInfo {{-1}}
        set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock clockRateSysInfo {{}}
        set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock clockResetSysInfo {{}}
        set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock resetDomainSysInfo {{-1}}
        add_connection {fab}_reset_bridge.out_reset/{fab}_{dev}_{itf}.reset
        set_connection_parameter_value {fab}_reset_bridge.out_reset/{fab}_{dev}_{itf}.reset clockDomainSysInfo {{-1}}
        set_connection_parameter_value {fab}_reset_bridge.out_reset/{fab}_{dev}_{itf}.reset clockResetSysInfo {{}}
        set_connection_parameter_value {fab}_reset_bridge.out_reset/{fab}_{dev}_{itf}.reset resetDomainSysInfo {{-1}}''')

        with open(args.tcl, 'a') as fOut:
            fOut.write('\n'.join(content))

    def conn_default_slv(self, fab, mst):
        content = []
        content.append(f'''
	add_connection {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave addressMapSysInfo {{}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave addressWidthSysInfo {{}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave arbitrationPriority {{1}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave baseAddress {{0x0000}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave defaultConnection {{1}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave domainAlias {{}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.burstAdapterImplementation {{GENERIC_CONVERTER}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.clockCrossingAdapter {{HANDSHAKE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.enableAllPipelines {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.enableEccProtection {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.enableInstrumentation {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.insertDefaultSlave {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.interconnectResetSource {{DEFAULT}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.interconnectType {{STANDARD}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.maxAdditionalLatency {{1}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.optimizeRdFifoSize {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.piplineType {{PIPELINE_STAGE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.responseFifoType {{REGISTER_BASED}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.syncResets {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.widthAdapterImplementation {{GENERIC_CONVERTER}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave slaveDataWidthSysInfo {{-1}}''')

        with open(args.tcl, 'a') as fOut:
            fOut.write('\n'.join(content))

   

    def conn_slv_dev(self, dev, fab, mst, addr):
        content = []
        content.append(f'''
        add_connection {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave addressMapSysInfo {{}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave addressWidthSysInfo {{}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave arbitrationPriority {{1}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave baseAddress {{{addr}}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave defaultConnection {{0}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave domainAlias {{}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.burstAdapterImplementation {{GENERIC_CONVERTER}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.clockCrossingAdapter {{HANDSHAKE}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.enableEccProtection {{FALSE}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.enableInstrumentation {{FALSE}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.insertDefaultSlave {{FALSE}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.interconnectResetSource {{DEFAULT}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.interconnectType {{STANDARD}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.maxAdditionalLatency {{1}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.syncResets {{FALSE}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.widthAdapterImplementation {{GENERIC_CONVERTER}}
        set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave slaveDataWidthSysInfo {{-1}}
        ''')

        with open(args.tcl, 'a') as fOut:
            fOut.write('\n'.join(content))
    

class SlaveReg(Register):
    def __init__(self, name, reg_type, base_addr, addr_width, fabric, slaves):
        self.reg_type = 'slv'
        super(SlaveReg, self).__init__(name, base_addr, addr_width, fabric)

    def inst_if(self):
        dev = self.name 
        fab = self.fabric
        aw = self.addr_width
        cap = 16
        content = []
        content.append(f'''
        add_component {fab}_{dev}_slv ip/{fab}/{fab}_{dev}_slv.ip axi4lite_shim {fab}_{dev}_slv 1.0
        load_component {fab}_{dev}_slv
        set_component_parameter_value AW {{{aw}}}
        set_component_parameter_value DW {{64}}
        set_component_project_property HIDE_FROM_IP_CATALOG {{false}}
        save_component
        load_instantiation {fab}_{dev}_slv
        remove_instantiation_interfaces_and_ports
        add_instantiation_interface clock clock INPUT
        set_instantiation_interface_parameter_value clock clockRate {{0}}
        set_instantiation_interface_parameter_value clock externallyDriven {{false}}
        set_instantiation_interface_parameter_value clock ptfSchematicName {{}}
        add_instantiation_interface_port clock clk clk 1 STD_LOGIC Input
        add_instantiation_interface reset reset INPUT
        set_instantiation_interface_parameter_value reset associatedClock {{clock}}
        set_instantiation_interface_parameter_value reset synchronousEdges {{DEASSERT}}
        add_instantiation_interface_port reset rst_n reset_n 1 STD_LOGIC Input
        add_instantiation_interface altera_axi4lite_slave axi4lite INPUT
        set_instantiation_interface_parameter_value altera_axi4lite_slave associatedClock {{clock}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave associatedReset {{reset}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave bridgesToMaster {{}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave combinedAcceptanceCapability {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingReads {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingTransactions {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingWrites {{{cap}/4}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave readAcceptanceCapability {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave readDataReorderingDepth {{1}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave trustzoneAware {{true}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave writeAcceptanceCapability {{{cap}/4}}
        add_instantiation_interface_port altera_axi4lite_slave s_awaddr awaddr {aw} STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_awprot awprot 3 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_awvalid awvalid 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_slave s_awready awready 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_wdata wdata 64 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_wstrb wstrb 8 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_wvalid wvalid 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_slave s_wready wready 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_bresp bresp 2 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_slave s_bvalid bvalid 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_bready bready 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_slave s_araddr araddr {aw} STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_arprot arprot 3 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_arvalid arvalid 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_slave s_arready arready 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_rdata rdata 64 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_slave s_rresp rresp 2 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_slave s_rvalid rvalid 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_rready rready 1 STD_LOGIC Input
        add_instantiation_interface altera_axi4lite_master axi4lite OUTPUT
        set_instantiation_interface_parameter_value altera_axi4lite_master associatedClock {{clock}}
        set_instantiation_interface_parameter_value altera_axi4lite_master associatedReset {{reset}}
        set_instantiation_interface_parameter_value altera_axi4lite_master combinedIssuingCapability {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_master maximumOutstandingReads {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_master maximumOutstandingTransactions {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_master maximumOutstandingWrites {{{cap}/4}}
        set_instantiation_interface_parameter_value altera_axi4lite_master readIssuingCapability {{{cap}}}
        set_instantiation_interface_parameter_value altera_axi4lite_master trustzoneAware {{true}}
        set_instantiation_interface_parameter_value altera_axi4lite_master writeIssuingCapability {{{cap}/4}}
        add_instantiation_interface_port altera_axi4lite_master m_awaddr awaddr {aw} STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_master m_awprot awprot 3 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_master m_awvalid awvalid 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_master m_awready awready 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_master m_wdata wdata 64 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_master m_wstrb wstrb 8 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_master m_wvalid wvalid 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_master m_wready wready 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_master m_bresp bresp 2 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_master m_bvalid bvalid 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_master m_bready bready 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_master m_araddr araddr {aw} STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_master m_arprot arprot 3 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_master m_arvalid arvalid 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_master m_arready arready 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_master m_rdata rdata 64 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_master m_rresp rresp 2 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_master m_rvalid rvalid 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_master m_rready rready 1 STD_LOGIC Output
        save_instantiation
        ''')

        with open(args.tcl, 'a') as fOut:
            fOut.write('\n'.join(content))



    def conn_dev_clkrst(self):
        dev = self.name
        fab = self.fabric
        itf = self.reg_type 
        content = []
        content.append(f'''
        add_connection {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock
        set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock clockDomainSysInfo {{-1}}
        set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock clockRateSysInfo {{}}
        set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock clockResetSysInfo {{}}
        set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock resetDomainSysInfo {{-1}}
        add_connection {fab}_reset_bridge.out_reset/{fab}_{dev}_{itf}.reset
        set_connection_parameter_value {fab}_reset_bridge.out_reset/{fab}_{dev}_{itf}.reset clockDomainSysInfo {{-1}}
        set_connection_parameter_value {fab}_reset_bridge.out_reset/{fab}_{dev}_{itf}.reset clockResetSysInfo {{}}
        set_connection_parameter_value {fab}_reset_bridge.out_reset/{fab}_{dev}_{itf}.reset resetDomainSysInfo {{-1}}''')

        with open(args.tcl, 'a') as fOut:
            fOut.write('\n'.join(content))
         
def write_heading(fabric, device, family):
    content = []
    content.append('package require -exact qsys 18.0')
    content.append(f'''  
    # create the system
	create_system {fabric}
        set_project_property DEVICE {device}
        set_project_property DEVICE_FAMILY {family}
	set_project_property HIDE_FROM_IP_CATALOG {{false}}
	set_use_testbench_naming_pattern 0 {{}}

    # add the components''')

    with open(args.tcl, 'w') as fOut:
        fOut.write('\n'.join(content))

def write_footer(dev):
    content = []
    content.append(f'''

    # set the the module properties
	set_module_property FILE {{{dev}.qsys}}
	set_module_property GENERATION_ID {{0x00000000}}
	set_module_property NAME {{{dev}}}

    # save the system
    sync_sysinfo_parameters
    save_system {dev}
    ''')

    with open(args.tcl, 'a') as fOut:
        fOut.write('\n'.join(content))

def inst_default_slv(fab):
    content = []
    content.append(f'''
        add_component {fab}_default_slv ip/{fab}/{fab}_default_slv.ip axi4lite_rsp {fab}_default_slv 1.0
        load_component {fab}_default_slv
        set_component_parameter_value AW {{6}}
        set_component_parameter_value DW {{64}}
        set_component_parameter_value RSP_STATUS {{0}}
        set_component_parameter_value RSP_VALUE {{0x0000000000000000}}
        set_component_project_property HIDE_FROM_IP_CATALOG {{false}}
        save_component
        load_instantiation {fab}_default_slv
        remove_instantiation_interfaces_and_ports
        add_instantiation_interface clock clock INPUT
        set_instantiation_interface_parameter_value clock clockRate {{0}}
        set_instantiation_interface_parameter_value clock externallyDriven {{false}}
        set_instantiation_interface_parameter_value clock ptfSchematicName {{}}
        add_instantiation_interface_port clock clk clk 1 STD_LOGIC Input
        add_instantiation_interface reset reset INPUT
        set_instantiation_interface_parameter_value reset associatedClock {{clock}}
        set_instantiation_interface_parameter_value reset synchronousEdges {{DEASSERT}}
        add_instantiation_interface_port reset rst_n reset_n 1 STD_LOGIC Input
        add_instantiation_interface altera_axi4lite_slave axi4lite INPUT
        set_instantiation_interface_parameter_value altera_axi4lite_slave associatedClock {{clock}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave associatedReset {{reset}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave bridgesToMaster {{}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave combinedAcceptanceCapability {{1}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingReads {{1}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingTransactions {{1}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingWrites {{1}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave readAcceptanceCapability {{1}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave readDataReorderingDepth {{1}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave trustzoneAware {{true}}
        set_instantiation_interface_parameter_value altera_axi4lite_slave writeAcceptanceCapability {{1}}
        add_instantiation_interface_port altera_axi4lite_slave s_awaddr awaddr 6 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_awprot awprot 3 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_awvalid awvalid 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_slave s_awready awready 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_wdata wdata 64 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_wstrb wstrb 8 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_wvalid wvalid 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_slave s_wready wready 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_bresp bresp 2 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_slave s_bvalid bvalid 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_bready bready 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_slave s_araddr araddr 6 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_arprot arprot 3 STD_LOGIC_VECTOR Input
        add_instantiation_interface_port altera_axi4lite_slave s_arvalid arvalid 1 STD_LOGIC Input
        add_instantiation_interface_port altera_axi4lite_slave s_arready arready 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_rdata rdata 64 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_slave s_rresp rresp 2 STD_LOGIC_VECTOR Output
        add_instantiation_interface_port altera_axi4lite_slave s_rvalid rvalid 1 STD_LOGIC Output
        add_instantiation_interface_port altera_axi4lite_slave s_rready rready 1 STD_LOGIC Input
        save_instantiation
    ''')


    with open(args.tcl, 'a') as fOut:
            fOut.write('\n'.join(content))
    
def conn_default_clkrst(fab):
    content = []
    content.append(f'''
        add_connection {fab}_clock_bridge.out_clk/{fab}_default_slv.clock
        set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_default_slv.clock clockDomainSysInfo {{-1}}
        set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_default_slv.clock clockRateSysInfo {{}}
        set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_default_slv.clock clockResetSysInfo {{}}
        set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_default_slv.clock resetDomainSysInfo {{-1}}
        add_connection {fab}_reset_bridge.out_reset/{fab}_default_slv.reset
        set_connection_parameter_value {fab}_reset_bridge.out_reset/{fab}_default_slv.reset clockDomainSysInfo {{-1}}
        set_connection_parameter_value {fab}_reset_bridge.out_reset/{fab}_default_slv.reset clockResetSysInfo {{}}
        set_connection_parameter_value {fab}_reset_bridge.out_reset/{fab}_default_slv.reset resetDomainSysInfo {{-1}}
    ''')
    
    with open(args.tcl, 'a') as fOut:
            fOut.write('\n'.join(content))

def conn_default_slv(fab, mst):
    content = []
    content.append(f'''
	add_connection {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave addressMapSysInfo {{}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave addressWidthSysInfo {{}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave arbitrationPriority {{1}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave baseAddress {{{addr}}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave defaultConnection {{0}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave domainAlias {{}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.burstAdapterImplementation {{GENERIC_CONVERTER}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.clockCrossingAdapter {{HANDSHAKE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.enableEccProtection {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.enableInstrumentation {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.insertDefaultSlave {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.interconnectResetSource {{DEFAULT}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.interconnectType {{STANDARD}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.maxAdditionalLatency {{1}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.syncResets {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave qsys_mm.widthAdapterImplementation {{GENERIC_CONVERTER}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_default_slv.altera_axi4lite_slave slaveDataWidthSysInfo {{-1}}
    ''')

    with open(args.tcl, 'a') as fOut:
        fOut.write('\n'.join(content))

def inst_clk_rst(fab):
    content = []
    content.append(f'''
	add_component {fab}_clock_bridge ip/{fab}/{fab}_clock_bridge.ip altera_clock_bridge {fab}_clock_bridge 
	load_component {fab}_clock_bridge
	set_component_parameter_value EXPLICIT_CLOCK_RATE {{0.0}}
	set_component_parameter_value NUM_CLOCK_OUTPUTS {{1}}
	set_component_project_property HIDE_FROM_IP_CATALOG {{false}}
	save_component
	load_instantiation {fab}_clock_bridge
	remove_instantiation_interfaces_and_ports
	add_instantiation_interface in_clk clock INPUT
	set_instantiation_interface_parameter_value in_clk clockRate {{0}}
	set_instantiation_interface_parameter_value in_clk externallyDriven {{false}}
	set_instantiation_interface_parameter_value in_clk ptfSchematicName {{}}
	add_instantiation_interface_port in_clk in_clk clk 1 STD_LOGIC Input
	add_instantiation_interface out_clk clock OUTPUT
	set_instantiation_interface_parameter_value out_clk associatedDirectClock {{in_clk}}
	set_instantiation_interface_parameter_value out_clk clockRate {{0}}
	set_instantiation_interface_parameter_value out_clk clockRateKnown {{false}}
	set_instantiation_interface_parameter_value out_clk externallyDriven {{false}}
	set_instantiation_interface_parameter_value out_clk ptfSchematicName {{}}
	set_instantiation_interface_sysinfo_parameter_value out_clk clock_rate {{0}}
	add_instantiation_interface_port out_clk out_clk clk 1 STD_LOGIC Output
	save_instantiation

	add_component {fab}_reset_bridge ip/{fab}/{fab}_reset_bridge.ip altera_reset_bridge {fab}_reset_bridge 
	load_component {fab}_reset_bridge
	set_component_parameter_value ACTIVE_LOW_RESET {{1}}
	set_component_parameter_value NUM_RESET_OUTPUTS {{1}}
	set_component_parameter_value SYNCHRONOUS_EDGES {{deassert}}
	set_component_parameter_value SYNC_RESET {{0}}
	set_component_parameter_value USE_RESET_REQUEST {{0}}
	set_component_project_property HIDE_FROM_IP_CATALOG {{false}}
	save_component
	load_instantiation {fab}_reset_bridge
	remove_instantiation_interfaces_and_ports
	add_instantiation_interface clk clock INPUT
	set_instantiation_interface_parameter_value clk clockRate {{0}}
	set_instantiation_interface_parameter_value clk externallyDriven {{false}}
	set_instantiation_interface_parameter_value clk ptfSchematicName {{}}
	add_instantiation_interface_port clk clk clk 1 STD_LOGIC Input
	add_instantiation_interface in_reset reset INPUT
	set_instantiation_interface_parameter_value in_reset associatedClock {{clk}}
	set_instantiation_interface_parameter_value in_reset synchronousEdges {{DEASSERT}}
	add_instantiation_interface_port in_reset in_reset_n reset_n 1 STD_LOGIC Input
	add_instantiation_interface out_reset reset OUTPUT
	set_instantiation_interface_parameter_value out_reset associatedClock {{clk}}
	set_instantiation_interface_parameter_value out_reset associatedDirectReset {{in_reset}}
	set_instantiation_interface_parameter_value out_reset associatedResetSinks {{in_reset}}
	set_instantiation_interface_parameter_value out_reset synchronousEdges {{DEASSERT}}
	add_instantiation_interface_port out_reset out_reset_n reset_n 1 STD_LOGIC Output
	save_instantiation
    ''')

    
    with open(args.tcl, 'a') as fOut:
        fOut.write('\n'.join(content))

def conn_clk_rst(fab):
    content = []
    content.append(f'''
	# add the connections
	add_connection {fab}_clock_bridge.out_clk/{fab}_reset_bridge.clk
	set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_reset_bridge.clk clockDomainSysInfo {{-1}}
	set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_reset_bridge.clk clockRateSysInfo {{}}
	set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_reset_bridge.clk clockResetSysInfo {{}}
	set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_reset_bridge.clk resetDomainSysInfo {{-1}}
    ''')

    with open(args.tcl, 'a') as fOut:
        fOut.write('\n'.join(content))

def exp_clk_rst(fab):
    content = []
    content.append(f'''
	# add the exports
	set_interface_property clk EXPORT_OF {fab}_clock_bridge.in_clk
	set_interface_property rst_n EXPORT_OF {fab}_reset_bridge.in_reset''')

    with open(args.tcl, 'a') as fOut:
        fOut.write('\n'.join(content))

def inst_mst_if(dev, fab, aw):
    cap = 16
    content = []
    content.append(f'''
	add_component {fab}_{dev}_mst ip/{fab}/{fab}_{dev}_mst.ip axi4lite_shim {fab}_{dev}_mst 1.0
	load_component {fab}_{dev}_mst
	set_component_parameter_value AW {{{aw}}}
	set_component_parameter_value DW {{64}}
          set_component_project_property HIDE_FROM_IP_CATALOG {{false}}
	save_component
	load_instantiation {fab}_{dev}_mst
	remove_instantiation_interfaces_and_ports
	add_instantiation_interface clock clock INPUT
	set_instantiation_interface_parameter_value clock clockRate {{0}}
	set_instantiation_interface_parameter_value clock externallyDriven {{false}}
	set_instantiation_interface_parameter_value clock ptfSchematicName {{}}
	add_instantiation_interface_port clock clk clk 1 STD_LOGIC Input
	add_instantiation_interface reset reset INPUT
	set_instantiation_interface_parameter_value reset associatedClock {{clock}}
	set_instantiation_interface_parameter_value reset synchronousEdges {{DEASSERT}}
	add_instantiation_interface_port reset rst_n reset_n 1 STD_LOGIC Input
	add_instantiation_interface altera_axi4lite_slave axi4lite INPUT
	set_instantiation_interface_parameter_value altera_axi4lite_slave associatedClock {{clock}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave associatedReset {{reset}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave bridgesToMaster {{}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave combinedAcceptanceCapability {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingReads {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingTransactions {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingWrites {{{cap}/4}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave readAcceptanceCapability {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave writeAcceptanceCapability {{{cap}/4}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave readDataReorderingDepth {{1}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave trustzoneAware {{true}}
	add_instantiation_interface_port altera_axi4lite_slave s_awaddr awaddr {aw} STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_slave s_awprot awprot 3 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_slave s_awvalid awvalid 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_slave s_awready awready 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_slave s_wdata wdata 64 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_slave s_wstrb wstrb 8 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_slave s_wvalid wvalid 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_slave s_wready wready 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_slave s_bresp bresp 2 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_slave s_bvalid bvalid 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_slave s_bready bready 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_slave s_araddr araddr {aw} STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_slave s_arprot arprot 3 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_slave s_arvalid arvalid 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_slave s_arready arready 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_slave s_rdata rdata 64 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_slave s_rresp rresp 2 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_slave s_rvalid rvalid 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_slave s_rready rready 1 STD_LOGIC Input
	add_instantiation_interface altera_axi4lite_master axi4lite OUTPUT
	set_instantiation_interface_parameter_value altera_axi4lite_master associatedClock {{clock}}
	set_instantiation_interface_parameter_value altera_axi4lite_master associatedReset {{reset}}
	set_instantiation_interface_parameter_value altera_axi4lite_master combinedIssuingCapability {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_master maximumOutstandingReads {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_master maximumOutstandingTransactions {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_master maximumOutstandingWrites {{{cap}/4}}
	set_instantiation_interface_parameter_value altera_axi4lite_master readIssuingCapability {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_master trustzoneAware {{true}}
	set_instantiation_interface_parameter_value altera_axi4lite_master writeIssuingCapability {{{cap}/4}}
	add_instantiation_interface_port altera_axi4lite_master m_awaddr awaddr {aw} STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_master m_awprot awprot 3 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_master m_awvalid awvalid 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_master m_awready awready 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_master m_wdata wdata 64 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_master m_wstrb wstrb 8 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_master m_wvalid wvalid 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_master m_wready wready 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_master m_bresp bresp 2 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_master m_bvalid bvalid 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_master m_bready bready 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_master m_araddr araddr {aw} STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_master m_arprot arprot 3 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_master m_arvalid arvalid 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_master m_arready arready 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_master m_rdata rdata 64 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_master m_rresp rresp 2 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_master m_rvalid rvalid 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_master m_rready rready 1 STD_LOGIC Output
	save_instantiation
    ''')

    with open(args.tcl, 'a') as fOut:
        fOut.write('\n'.join(content))

def inst_slv_if(dev, fab, aw):
    cap = 16
    content = []
    content.append(f'''
	add_component {fab}_{dev}_slv ip/{fab}/{fab}_{dev}_slv.ip axi4lite_shim {fab}_{dev}_slv 1.0
	load_component {fab}_{dev}_slv
	set_component_parameter_value AW {{{aw}}}
	set_component_parameter_value DW {{64}}
	set_component_project_property HIDE_FROM_IP_CATALOG {{false}}
	save_component
	load_instantiation {fab}_{dev}_slv
	remove_instantiation_interfaces_and_ports
	add_instantiation_interface clock clock INPUT
	set_instantiation_interface_parameter_value clock clockRate {{0}}
	set_instantiation_interface_parameter_value clock externallyDriven {{false}}
	set_instantiation_interface_parameter_value clock ptfSchematicName {{}}
	add_instantiation_interface_port clock clk clk 1 STD_LOGIC Input
	add_instantiation_interface reset reset INPUT
	set_instantiation_interface_parameter_value reset associatedClock {{clock}}
	set_instantiation_interface_parameter_value reset synchronousEdges {{DEASSERT}}
	add_instantiation_interface_port reset rst_n reset_n 1 STD_LOGIC Input
	add_instantiation_interface altera_axi4lite_slave axi4lite INPUT
	set_instantiation_interface_parameter_value altera_axi4lite_slave associatedClock {{clock}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave associatedReset {{reset}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave bridgesToMaster {{}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave combinedAcceptanceCapability {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingReads {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingTransactions {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave maximumOutstandingWrites {{{cap}/4}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave readAcceptanceCapability {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave readDataReorderingDepth {{1}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave trustzoneAware {{true}}
	set_instantiation_interface_parameter_value altera_axi4lite_slave writeAcceptanceCapability {{{cap}/4}}
	add_instantiation_interface_port altera_axi4lite_slave s_awaddr awaddr {aw} STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_slave s_awprot awprot 3 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_slave s_awvalid awvalid 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_slave s_awready awready 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_slave s_wdata wdata 64 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_slave s_wstrb wstrb 8 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_slave s_wvalid wvalid 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_slave s_wready wready 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_slave s_bresp bresp 2 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_slave s_bvalid bvalid 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_slave s_bready bready 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_slave s_araddr araddr {aw} STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_slave s_arprot arprot 3 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_slave s_arvalid arvalid 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_slave s_arready arready 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_slave s_rdata rdata 64 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_slave s_rresp rresp 2 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_slave s_rvalid rvalid 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_slave s_rready rready 1 STD_LOGIC Input
	add_instantiation_interface altera_axi4lite_master axi4lite OUTPUT
	set_instantiation_interface_parameter_value altera_axi4lite_master associatedClock {{clock}}
	set_instantiation_interface_parameter_value altera_axi4lite_master associatedReset {{reset}}
	set_instantiation_interface_parameter_value altera_axi4lite_master combinedIssuingCapability {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_master maximumOutstandingReads {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_master maximumOutstandingTransactions {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_master maximumOutstandingWrites {{{cap}/4}}
	set_instantiation_interface_parameter_value altera_axi4lite_master readIssuingCapability {{{cap}}}
	set_instantiation_interface_parameter_value altera_axi4lite_master trustzoneAware {{true}}
	set_instantiation_interface_parameter_value altera_axi4lite_master writeIssuingCapability {{{cap}/4}}
	add_instantiation_interface_port altera_axi4lite_master m_awaddr awaddr {aw} STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_master m_awprot awprot 3 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_master m_awvalid awvalid 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_master m_awready awready 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_master m_wdata wdata 64 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_master m_wstrb wstrb 8 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_master m_wvalid wvalid 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_master m_wready wready 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_master m_bresp bresp 2 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_master m_bvalid bvalid 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_master m_bready bready 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_master m_araddr araddr {aw} STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_master m_arprot arprot 3 STD_LOGIC_VECTOR Output
	add_instantiation_interface_port altera_axi4lite_master m_arvalid arvalid 1 STD_LOGIC Output
	add_instantiation_interface_port altera_axi4lite_master m_arready arready 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_master m_rdata rdata 64 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_master m_rresp rresp 2 STD_LOGIC_VECTOR Input
	add_instantiation_interface_port altera_axi4lite_master m_rvalid rvalid 1 STD_LOGIC Input
	add_instantiation_interface_port altera_axi4lite_master m_rready rready 1 STD_LOGIC Output
	save_instantiation
    ''')

    with open(args.tcl, 'a') as fOut:
        fOut.write('\n'.join(content))
    

def conn_dev_clkrst(dev, fab, itf):
    content = []
    content.append(f'''
	add_connection {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock
	set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock clockDomainSysInfo {{-1}}
	set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock clockRateSysInfo {{}}
	set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock clockResetSysInfo {{}}
	set_connection_parameter_value {fab}_clock_bridge.out_clk/{fab}_{dev}_{itf}.clock resetDomainSysInfo {{-1}}
	add_connection {fab}_reset_bridge.out_reset/{fab}_{dev}_{itf}.reset
	set_connection_parameter_value {fab}_reset_bridge.out_reset/{fab}_{dev}_{itf}.reset clockDomainSysInfo {{-1}}
	set_connection_parameter_value {fab}_reset_bridge.out_reset/{fab}_{dev}_{itf}.reset clockResetSysInfo {{}}
	set_connection_parameter_value {fab}_reset_bridge.out_reset/{fab}_{dev}_{itf}.reset resetDomainSysInfo {{-1}}''')

    with open(args.tcl, 'a') as fOut:
        fOut.write('\n'.join(content))

def conn_slv_dev(dev, fab, mst, addr):
    content = []
    content.append(f'''
	add_connection {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave addressMapSysInfo {{}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave addressWidthSysInfo {{}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave arbitrationPriority {{1}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave baseAddress {{{addr}}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave defaultConnection {{0}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave domainAlias {{}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.burstAdapterImplementation {{GENERIC_CONVERTER}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.clockCrossingAdapter {{HANDSHAKE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.enableEccProtection {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.enableInstrumentation {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.insertDefaultSlave {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.interconnectResetSource {{DEFAULT}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.interconnectType {{STANDARD}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.maxAdditionalLatency {{1}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.syncResets {{FALSE}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave qsys_mm.widthAdapterImplementation {{GENERIC_CONVERTER}}
	set_connection_parameter_value {fab}_{mst}_mst.altera_axi4lite_master/{fab}_{dev}_slv.altera_axi4lite_slave slaveDataWidthSysInfo {{-1}}
    ''')

    with open(args.tcl, 'a') as fOut:
        fOut.write('\n'.join(content))

def conn_mst_dev(dev, fab, slv, addr):
    content = []
    content.append(f'''
	add_connection {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave addressMapSysInfo {{}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave addressWidthSysInfo {{}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave arbitrationPriority {{1}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave baseAddress {{$addr}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave defaultConnection {{0}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave domainAlias {{}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave qsys_mm.burstAdapterImplementation {{GENERIC_CONVERTER}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave qsys_mm.clockCrossingAdapter {{HANDSHAKE}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave qsys_mm.enableEccProtection {{FALSE}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave qsys_mm.enableInstrumentation {{FALSE}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave qsys_mm.insertDefaultSlave {{FALSE}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave qsys_mm.interconnectResetSource {{DEFAULT}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave qsys_mm.interconnectType {{STANDARD}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave qsys_mm.maxAdditionalLatency {{1}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave qsys_mm.syncResets {{FALSE}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave qsys_mm.widthAdapterImplementation {{GENERIC_CONVERTER}}
	set_connection_parameter_value {fab}_{dev}_mst.altera_axi4lite_master/{fab}_{slv}_slv.altera_axi4lite_slave slaveDataWidthSysInfo {{-1}}
    ''')

    with open(args.tcl, 'a') as fOut:
        fOut.write('\n'.join(content))
    
def exp_dev_if(dev, fab, itf):
    if itf == 'slv':
        di = 'master'
    elif itf == 'mst':
        di = 'slave'

    content = []
    content.append(f'''
	set_interface_property {fab}_{dev}_{itf} EXPORT_OF {fab}_{dev}_{itf}.altera_axi4lite_{di}''')
    
    with open(args.tcl, 'a') as fOut:
        fOut.write('\n'.join(content))
    
def write_qsys_output(reg_mapping, device, family):
    fabric = args.fabric_name
    write_heading(fabric, device, family)
    inst_clk_rst(fabric)
    conn_clk_rst(fabric)
    exp_clk_rst(fabric)
    #instantate & connect rst/clk default slave
    inst_default_slv(fabric)
    conn_default_clkrst(fabric)

    for slv in reg_mapping['slv'].values():
        slv.inst_if()
    for mst in reg_mapping['mst'].values():
        mst.inst_if()
    for slv in reg_mapping['slv'].values():
        slv.conn_dev_clkrst()

    for mst in reg_mapping['mst'].values():
        mst.conn_dev_clkrst()
        # connect each master to default slave
        mst.conn_default_slv(fabric, mst.name)
        for mst_slv in mst.slaves:
            slave = reg_mapping['slv'][mst_slv]
            mst.conn_slv_dev(slave.name, fabric, mst.name, slave.base_addr)

    for mst in reg_mapping['mst'].values():
        exp_dev_if(mst.name, fabric, mst.reg_type)
    for slv in reg_mapping['slv'].values():
        exp_dev_if(slv.name, fabric, slv.reg_type)

    write_footer(fabric)
    
        
def find_fabric_ports(features):
    enabled_ports = set()
    for feature_name, feature_values in features.items():
        if 'fabric_ports' in feature_values.keys():
            for fp in feature_values['fabric_ports']:
                enabled_ports.add(fp)

    return enabled_ports

def read_configuration():
    reg_config = None
    design_config = None

    with open(args.fabric_def) as fIn:
        print(f"Reading {args.fabric_def} for Fabric {args.fabric_name} configuration")
        reg_config = fIn.readlines()

    #with open('features_config.yaml') as f:
    #with open(args.cfg) as f:
     #   design_config = yaml.load(f, Loader=yaml.FullLoader)

    #features = design_config['features']
    #enabled_ports = find_fabric_ports(features)
    #print(enabled_ports)

    reg_mapping = {'mst':{}, 
                   'slv':{}}

    fabric = args.fabric_name
    for entry in reg_config:
        if entry.startswith('#'):
            continue

        reg_device, reg_type, base_addr, addr_width, slaves = entry.split()
        print(f"Processing {reg_device} {reg_type}")
        #if reg_device not in enabled_ports:
            #continue 
        if reg_type == 'mst':
            #master_reg = MasterReg(reg_device, reg_type, base_addr, addr_width, fabric, slaves, enabled_ports)
            master_reg = MasterReg(reg_device, reg_type, base_addr, addr_width, fabric, slaves)
            master_reg.show_slaves()
            reg_mapping['mst'][master_reg.name] = master_reg
        else:
            slave_reg = SlaveReg(reg_device, reg_type, base_addr, addr_width, fabric, slaves) 
            #if reg_device in enabled_ports:
            reg_mapping['slv'][slave_reg.name] = slave_reg

    return reg_mapping
    

def write_fabric_design_output(reg_mapping):
    fabric = args.fabric_name
    content = []
    content.append(f"set_global_assignment -name QSYS_FILE ../ip_lib/src/pd_qsys/fabric/{fabric}.qsys")
    content.append(f"set_global_assignment -name IP_FILE ../ip_lib/src/pd_qsys/fabric/ip/{fabric}/{fabric}_clock_bridge.ip")
    content.append(f"set_global_assignment -name IP_FILE ../ip_lib/src/pd_qsys/fabric/ip/{fabric}/{fabric}_reset_bridge.ip")
    content.append("\n")

    for mst in reg_mapping['mst']:
        content.append(f"set_global_assignment -name IP_FILE ../ip_lib/src/pd_qsys/fabric/ip/{fabric}/{fabric}_{mst}_mst.ip")
    for slv in reg_mapping['slv']:
        content.append(f"set_global_assignment -name IP_FILE ../ip_lib/src/pd_qsys/fabric/ip/{fabric}/{fabric}_{slv}_slv.ip")

    
    with open(f"{fabric}_design_files.tcl", 'w') as fOut:
        fOut.write('\n'.join(content))
        
    
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--tcl', help="This is the output tcl file path")
    #parser.add_argument('--cfg', type=str, help="Fabric configuration file")
    parser.add_argument('--fabric_def', help="Fabric definition")
    parser.add_argument('--fabric_name', help="Fabric name")

    args = parser.parse_args()
    
    reg_mapping = read_configuration()
    write_fabric_design_output(reg_mapping)
    write_qsys_output(reg_mapping, 'AGFB014R24A2E2V', 'Agilex')

    
