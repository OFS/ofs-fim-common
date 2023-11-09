# Copyright (C) 2001-2021 Intel Corporation
# SPDX-License-Identifier: MIT


#####################################################################
#
# THIS IS AN AUTO-GENERATED FILE!
# -------------------------------
# If you modify this files, all your changes will be lost if you
# regenerate the core!
#
# FILE DESCRIPTION
# ----------------
# This file specifies the timing constraints for the EMIF local_reset_combiner
# component, which is instantiated as part of the EMIF example design.

set ::syn_flow 0
set ::sta_flow 0
set ::fit_flow 0
set ::pow_flow 0

if { $::TimeQuestInfo(nameofexecutable) == "quartus_map" || $::TimeQuestInfo(nameofexecutable) == "quartus_syn" } {
    set ::syn_flow 1
} elseif { $::TimeQuestInfo(nameofexecutable) == "quartus_sta" } {
    set ::sta_flow 1
} elseif { $::TimeQuestInfo(nameofexecutable) == "quartus_fit" } {
    set ::fit_flow 1
} elseif { $::TimeQuestInfo(nameofexecutable) == "quartus_pow" } {
    set ::pow_flow 1
}

proc apply_sdc_reset_synchronizer {hier_path} {
    global ::fit_flow

    set tmp_pin [get_pins -nowarn ${hier_path}|clrn]
    if {[get_collection_size $tmp_pin] > 0} {
        if {$::fit_flow == 1} {
            set_multicycle_path -through $tmp_pin -to $hier_path -setup 7 -end
            set_multicycle_path -through $tmp_pin -to $hier_path -hold 6 -end
        } else {
            set_false_path -through $tmp_pin -to $hier_path
        }
    }
}

proc apply_sdc_data_synchronizer_input {hier_path} {
    global ::fit_flow

    set tmp_pin [get_pins -nowarn ${hier_path}|d]
    if {[get_collection_size $tmp_pin] > 0} {
        if {$::fit_flow == 1} {
            set_multicycle_path -through $tmp_pin -to $hier_path -setup 7 -end
            set_multicycle_path -through $tmp_pin -to $hier_path -hold 6 -end
        } else {
            set_false_path -through $tmp_pin -to $hier_path
        }
    }
}

apply_sdc_reset_synchronizer "reset_n_int_sync_inst|*"
apply_sdc_data_synchronizer_input "reset_n_int_sync_inst|din_s1"
