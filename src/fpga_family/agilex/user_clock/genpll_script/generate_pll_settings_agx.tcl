# Copyright (C) 1992-2015 Intel Corporation
# SPDX-License-Identifier: MIT

post_message "Running adjust PLLs script"
 
# Required packages
package require ::quartus::project
package require ::quartus::report
package require ::quartus::flow
#package require ::quartus::atoms
package ifneeded ::altera::pll_legality 1.0 {
  switch $tcl_platform(platform) {
    windows {
      load [file join $::quartus(binpath) qcl_pll_legality_tcl.dll] pll_legality
    }
    unix {
      load [file join $::quartus(binpath) libqcl_pll_legality_tcl[info sharedlibextension]] pll_legality
    }
  }
}
package require ::quartus::qcl_pll
package require ::quartus::pll::legality

# Definitions
set k_clk_name "*kernel_pll*outclk0"
set k_clk2x_name "*kernel_pll*outclk1"
set k_fmax -1
set jitter_compensation 0.01


# Utility functions
# ------------------------------------------------------------------------------------------
proc get_nearest_achievable_frequency { desired_kernel_clk  \
                                        refclk_freq \
                                        device_family \
                                        device_speedgrade \
                                        kernel2x_clk_unused } {
#
# Description :  Returns the closest achievable IOPLL frequency less than or
#                equal to desired_kernel_clk.
#
# Parameters :
#    desired_kernel_clk  - The desired frequency in MHz (floating point)
#    refclk_freq         - The IOPLL's reference clock frequency in MHz (floating point)
#    device_family       - The device family ("Arria 10" or "Stratix 10")
#    device_speedgrade   - The device speedgrade (1, 2 or 3)
#    kernel2x_clk_unused - 0->kernel2x_clk is used, 1->kernel2x_clk is not used
#
# Assumptions :
#    - There are two desired output clocks, the kernel_clk and a kernel_clk_2x
#    - Both clocks have zero phase shift
#    - The desired_kernel_clk frequency is > 10 MHz
#
# -------------------------------------------------------------------------------------------
 
  if { $kernel2x_clk_unused == 1 } {
    # In case the kernel2x_clk is not used in our design we can simplify and just
    # compute the nearest achievable frequency for the kernel_clk.
    set desired_clk $desired_kernel_clk
  } else {
    # If the kernel2x_clk frequency is achievable from a given VCO frequency,
    # then so must be the kernel_clk (assuming that it is not absurdly low).
    # So, we can simply and compute for an IOPLL with a single clock output of kernel2x_clk.
    set desired_clk [expr $desired_kernel_clk * 2]
  }
 
  # Use array get to ensure correct input formatting (and avoid curly braces)
  set desired_output(0) [list -type c -index 0 -freq $desired_clk -phase 0.0 -is_degrees false -duty 50.0]
  set desired_counter [array get desired_output]
 
  # Prepare the arguments for a call to the PLL legality package.
  # The non-obvious parameters here are all effectively don't cares.
  set ref_list [list  -family                       $device_family \
                      -speedgrade                   $device_speedgrade \
                      -refclk_freq                  $refclk_freq \
                      -is_fractional                false \
                      -compensation_mode            direct \
                      -is_counter_cascading_enabled false \
                      -x                            32 \
                      -validated_counter_values     {} \
                      -desired_counter_values       $desired_counter]
 
  if {[catch {::quartus::pll::legality::retrieve_output_clock_frequency_list $ref_list} result]} {
    post_message "Call to retrieve_output_clock_frequency_list failed because:"
    post_message $result
    return TCL_ERROR
    # ERROR
  }
 
  # We get a list of six legal frequencies for kernel_clk_2x
  array set result_array $result
  set freq_list $result_array(freq)
 
  # Pick the closest frequency that's still less than the desired frequency
  # Recover the legal kernel_clk frequencies as we go
  set best_freq 0
  set possible_kernel_freqs {}
 
  foreach freq_temp $freq_list {
    if { $kernel2x_clk_unused == 1 } {
      # We are looking for the closest possible frequency that
      # is just below the desired kernel clock
      set freq $freq_temp
    } else {
      # We are looking for the closest possible frequency just
      # below the desired kernel clock being half the frequency
      # of the kernel2x clock
      set freq [expr double($freq_temp) / 2]
    }
    lappend possible_kernel_freqs $freq
    if { $freq > $desired_kernel_clk } {
      # The frequency exceeds fmax -- no good.
    } elseif { $freq > $best_freq } {
      set best_freq $freq
    }
  }
 
  if {$best_freq == 0} {
    post_message "All of the frequencies were too high!"
    return TCL_ERROR
    # ERROR
  } else {
    return $best_freq
    # SUCCESS!
  }
 
}

# ------------------------------------------------------------------------------------------
proc adjust_iopll_frequency_in_postfit_netlist { device_family \
                                                 device_speedgrade \
                                                 reference_frequency \
						 legalized_kernel_clk \
						 kernel2x_clk_unused } {
#
# Description :  Configures IOPLL "pll_name" parameter settings to produce a new output frequency
#                of legalized_kernel_clk.  This must be a legal setting for success.
#
# Parameters :
#    design_name          - Design name (i.e. <design_name>.qpf)
#    pll_name             - The full hierarchical name of the target IOPLL in the design
#    device_family	  - The device family ("Arria 10" or "Stratix 10")
#    device_speedgrade    - The device speedgrade (1, 2 or 3)
#    legalized_kernel_clk - The new kernel_clk frequency (legalized by get_nearest_achievable_frequency)
#    kernel2x_clk_unused  - 0->kernel2x_clk is used, 1->kernel2x_clk is not used
#
# Assumptions :
#    - The legalized_kernel_clk frequency is, in fact, legal
#    - There are two desired output clocks, the kernel_clk and a kernel_clk_2x
#    - Both clocks have zero phase shift
#    - The PLL is set to low (auto) bandwidth
#
# -------------------------------------------------------------------------------------------
  # Desired output frequencies (kernel_clk and kernel_clk_2x)
  set refclk $reference_frequency
  set outclk0 $legalized_kernel_clk
  if { $kernel2x_clk_unused == 1  || $outclk0 > 400} {
    # kernel2x_clk is unused, in this case we set the IOPLL output to be
    # the same frequency as the kernel1x_clk
     # Or outclk1 doesn't go over 800 MHz
    set outclk1 $outclk0
  } else {
    # kernel2x_clk is used, it is double the frequency of kernel1x_clk
    set outclk1 [expr $outclk0 * 2]
  }
 
  set desired_output(0) [list -type c -index 0 -freq $outclk0 -phase 0.0 -is_degrees false -duty 50.0]
  set desired_output(1) [list -type c -index 0 -freq $outclk1 -phase 0.0 -is_degrees false -duty 50.0]
  set desired_counters  [array get desired_output]
 
  # Compute the new IOPLL settings
  set result 0
  set error 0
 
  global acds_version
    set error [catch {get_physical_parameters_for_generation \
          -prot_mode "BASIC" \
          -using_adv_mode false \
          -device_family $device_family \
          -device_speedgrade $device_speedgrade \
          -compensation_mode direct \
          -refclk_freq $refclk \
          -is_fractional false \
          -x 32 \
          -m 1 \
          -n 1 \
          -k 1 \
          -bw_preset Low \
          -is_counter_cascading_enabled false \
          -validated_counter_settings [array get desired_output] \
          } result]
 
  if {$error} {
    post_message "Failed to generate new IOPLL settings.  The requested output frequency might have been illegal."
    post_message $result
    return TCL_ERROR
    # ERROR
  }
 
  # Extract the new IOPLL settings
  array set result_array $result

  set mif_pll_bwctrl $result_array(bw)
  set mif_pll_bwctrl_old $mif_pll_bwctrl
  switch $mif_pll_bwctrl {
    pll_bw_res_setting0  {set mif_pll_bwctrl 0}
    pll_bw_res_setting1  {set mif_pll_bwctrl 1}
    pll_bw_res_setting2  {set mif_pll_bwctrl 2}
    pll_bw_res_setting3  {set mif_pll_bwctrl 3}
    pll_bw_res_setting4  {set mif_pll_bwctrl 4}
    pll_bw_res_setting5  {set mif_pll_bwctrl 5}
    pll_bw_res_setting6  {set mif_pll_bwctrl 6}
    pll_bw_res_setting7  {set mif_pll_bwctrl 7}
    pll_bw_res_setting8  {set mif_pll_bwctrl 8}
    pll_bw_res_setting9  {set mif_pll_bwctrl 9}
    pll_bw_res_setting10 {set mif_pll_bwctrl 10}
    default {pll_send_message error "Unknown Bandwidth Setting value $mif_pll_bwctrl"}
  }


  set mif_pll_cp_current $result_array(cp)
  set mif_pll_cp_current_old $mif_pll_cp_current
  switch $mif_pll_cp_current {
	pll_cp_setting0   {set mif_pll_cp_current 0}
	pll_cp_setting1   {set mif_pll_cp_current 1}
	pll_cp_setting2   {set mif_pll_cp_current 2}
	pll_cp_setting3   {set mif_pll_cp_current 3}
	pll_cp_setting4   {set mif_pll_cp_current 4}
	pll_cp_setting5   {set mif_pll_cp_current 5}
	pll_cp_setting6   {set mif_pll_cp_current 6}
	pll_cp_setting7   {set mif_pll_cp_current 8}
	pll_cp_setting8   {set mif_pll_cp_current 9}
	pll_cp_setting9   {set mif_pll_cp_current 10}
	pll_cp_setting10  {set mif_pll_cp_current 11}
	pll_cp_setting11  {set mif_pll_cp_current 12}
	pll_cp_setting12  {set mif_pll_cp_current 13}
	pll_cp_setting13  {set mif_pll_cp_current 14}
	pll_cp_setting14  {set mif_pll_cp_current 16}
	pll_cp_setting15  {set mif_pll_cp_current 17}
	pll_cp_setting16  {set mif_pll_cp_current 18}
	pll_cp_setting17  {set mif_pll_cp_current 19}
	pll_cp_setting18  {set mif_pll_cp_current 20}
	pll_cp_setting19  {set mif_pll_cp_current 21}
	pll_cp_setting20  {set mif_pll_cp_current 22}
	pll_cp_setting21  {set mif_pll_cp_current 24}
	pll_cp_setting22  {set mif_pll_cp_current 25}
	pll_cp_setting23  {set mif_pll_cp_current 26}
	pll_cp_setting24  {set mif_pll_cp_current 27}
	pll_cp_setting25  {set mif_pll_cp_current 28}
	pll_cp_setting26  {set mif_pll_cp_current 29}
	pll_cp_setting27  {set mif_pll_cp_current 30}
	pll_cp_setting28  {set mif_pll_cp_current 32}
	pll_cp_setting29  {set mif_pll_cp_current 33}
	pll_cp_setting30  {set mif_pll_cp_current 34}
	pll_cp_setting31  {set mif_pll_cp_current 35}
	pll_cp_setting32  {set mif_pll_cp_current 36}
	pll_cp_setting33  {set mif_pll_cp_current 37}
	pll_cp_setting34  {set mif_pll_cp_current 38}
	pll_cp_setting35  {set mif_pll_cp_current 40}
	default {pll_send_message error "Unknown Charge Pump value $mif_pll_cp_current"}
  }

  if { $device_family == "Stratix 10" || $device_family == "Agilex"} {   	
    set mif_pll_ripplecap $result_array(ripplecap)
    set mif_pll_ripplecap_old $mif_pll_ripplecap
    switch $mif_pll_ripplecap {
      pll_ripplecap_setting0   {set mif_pll_ripplecap 0}
      pll_ripplecap_setting1   {set mif_pll_ripplecap 1}
      pll_ripplecap_setting2   {set mif_pll_ripplecap 2}
      pll_ripplecap_setting3   {set mif_pll_ripplecap 3}
      default {pll_send_message error "Unknown Ripplecap value $mif_pll_ripplecap"}
    }
  }
 

  # M counter settings
  array set m_array $result_array(m)
  set m_hi_div      $m_array(m_high)
  set m_lo_div      $m_array(m_low)
  set m_bypass      $m_array(m_bypass_en)
  set m_duty_tweak  $m_array(m_tweak)
 
  # N counter settings
  array set n_array $result_array(n)
  set n_hi_div      $n_array(n_high)
  set n_lo_div      $n_array(n_low)
  set n_bypass      $n_array(n_bypass_en)
  set n_duty_tweak  $n_array(n_tweak)
 
  # VCO frequency
  set vco_freq      "[round_to_atom_precision $result_array(vco_freq)] MHz"
 
  # BW & CP current settings
  post_message "Result back $result_array(bw)"
  
  
  # C counter settings
  array set c_array $result_array(c)
 
  # C0 counter settings
  array set c0_array $c_array(0)
  set outclk_freq0  "[round_to_atom_precision $c0_array(freq)] MHz"
  set c0_hi_div     $c0_array(c_high)
  set c0_lo_div     $c0_array(c_low)
  set c0_bypass     $c0_array(c_bypass_en)
  set c0_duty_tweak $c0_array(c_tweak)
 
  # C1 counter settings
  array set c1_array $c_array(1)
  set outclk_freq1  "[round_to_atom_precision $c1_array(freq)] MHz"
  set c1_hi_div     $c1_array(c_high)
  set c1_lo_div     $c1_array(c_low)
  set c1_bypass     $c1_array(c_bypass_en)
  set c1_duty_tweak $c1_array(c_tweak)
 
  # M COUNTER
  set m_value [expr (($m_duty_tweak & 1)<<17)+(($m_bypass & 1)<<16)+(($m_hi_div & 0xFF)<<8)+($m_lo_div & 0xFF)]
 
  # N COUNTER
  set n_value [expr (($n_duty_tweak & 1)<<17)+(($n_bypass & 1)<<16)+(($n_hi_div & 0xFF)<<8)+($n_lo_div & 0xFF)]
 
  # C0 COUNTER
  set c0_value [expr (($c0_duty_tweak & 1)<<17)+(($c0_bypass & 1)<<16)+(($c0_hi_div & 0xFF)<<8)+($c0_lo_div & 0xFF)]
 
  # C1 COUNTER
  set c1_value [expr (($c1_duty_tweak & 1)<<17)+(($c1_bypass & 1)<<16)+(($c1_hi_div & 0xFF)<<8)+($c1_lo_div & 0xFF)]

  # BW SETTING
  set mif_pll_bwctrl_value [expr (($mif_pll_bwctrl & 0xF)<<6)]
  

  # Write out pll_config.bin file
  set pll_config_file "pll_config.bin"
  set pll_config [open $pll_config_file w]
 
  set freq_kHz [expr int($legalized_kernel_clk * 1000)]
 
  if { $device_family == "Arria 10" } {
    puts $pll_config "$freq_kHz $m_value $n_value $c0_value $c1_value $mif_pll_bwctrl_value $mif_pll_cp_current"
  }
  if { $device_family == "Stratix 10"} {
    puts $pll_config "$freq_kHz $m_value $n_value $c0_value $c1_value $mif_pll_bwctrl_value $mif_pll_cp_current $mif_pll_ripplecap"
  }
  if { $device_family == "Agilex"} {
    # c1->usr_clk, c0->usr_clk_2
    puts $pll_config "$freq_kHz $m_value $n_value $c0_value $c1_value $mif_pll_bwctrl_value $mif_pll_cp_current $mif_pll_ripplecap"
    post_message "Updating the bin file $freq_kHz $m_value $n_value $c0_value $c1_value $mif_pll_bwctrl_value $mif_pll_cp_current $mif_pll_ripplecap"
  }
 
  close $pll_config
 
	# Apply the new settings:
	set fast_compile 1
	if {!$fast_compile} {
	    # Modify by pxx
		if {$device_family == "Agilex"} {
			set_atom_node_info -key TIME_IOPLL_OUTCLK1 -node $node $outclk_freq0
			set_atom_node_info -key TIME_IOPLL_OUTCLK2 -node $node $outclk_freq1
			set_atom_node_info -key TIME_IOPLL_VCO -node $node $vco_freq
 
			set_atom_node_info -key INT_IOPLL_M_COUNTER_HIGH            -node $node    $m_hi_div
			set_atom_node_info -key INT_IOPLL_M_COUNTER_LOW            -node $node    $m_lo_div
			set_atom_node_info -key BOOL_IOPLL_M_COUNTER_BYPASS_EN        -node $node    $m_bypass
			set_atom_node_info -key BOOL_IOPLL_M_COUNTER_EVEN_DUTY_EN     -node $node    $m_duty_tweak
 
			set_atom_node_info -key INT_IOPLL_N_COUNTER_HIGH            -node $node    $n_hi_div
			set_atom_node_info -key INT_IOPLL_N_COUNTER_LOW            -node $node    $n_lo_div
			set_atom_node_info -key BOOL_IOPLL_N_COUNTER_BYPASS_EN        -node $node    $n_bypass
			set_atom_node_info -key BOOL_IOPLL_N_COUNTER_ODD_DIV_DUTY_EN  -node $node    $n_duty_tweak
 
			set_atom_node_info -key INT_IOPLL_C1_HIGH          -node $node    $c0_hi_div
			set_atom_node_info -key INT_IOPLL_C1_LOW          -node $node    $c0_lo_div
			set_atom_node_info -key BOOL_IOPLL_C1_BYPASS_EN      -node $node    $c0_bypass
			set_atom_node_info -key BOOL_IOPLL_C1_EVEN_DUTY_EN   -node $node    $c0_duty_tweak
 
			set_atom_node_info -key INT_IOPLL_C2_HIGH          -node $node    $c1_hi_div
			set_atom_node_info -key INT_IOPLL_C2_LOW          -node $node    $c1_lo_div
			set_atom_node_info -key BOOL_IOPLL_C2_BYPASS_EN      -node $node    $c1_bypass
			set_atom_node_info -key BOOL_IOPLL_C2_EVEN_DUTY_EN   -node $node    $c1_duty_tweak
 
			set_atom_node_info -key ENUM_IOPLL_BW_MODE             -node $node    $mif_pll_bw_mode
			
		} else {
			post_message "set_atom_node_info -key TIME_OUTPUT_CLOCK_FREQUENCY_0 -node $node $outclk_freq0"
			set_atom_node_info -key TIME_OUTPUT_CLOCK_FREQUENCY_0     -node $node    $outclk_freq0
			set_atom_node_info -key TIME_OUTPUT_CLOCK_FREQUENCY_1     -node $node    $outclk_freq1
			set_atom_node_info -key TIME_VCO_FREQUENCY                -node $node    $vco_freq
 
			set_atom_node_info -key INT_IOPLL_M_CNT_HI_DIV            -node $node    $m_hi_div
			set_atom_node_info -key INT_IOPLL_M_CNT_LO_DIV            -node $node    $m_lo_div
			set_atom_node_info -key BOOL_IOPLL_M_CNT_BYPASS_EN        -node $node    $m_bypass
			set_atom_node_info -key BOOL_IOPLL_M_CNT_EVEN_DUTY_EN     -node $node    $m_duty_tweak
 
			set_atom_node_info -key INT_IOPLL_N_CNT_HI_DIV            -node $node    $n_hi_div
			set_atom_node_info -key INT_IOPLL_N_CNT_LO_DIV            -node $node    $n_lo_div
			set_atom_node_info -key BOOL_IOPLL_N_CNT_BYPASS_EN        -node $node    $n_bypass
			set_atom_node_info -key BOOL_IOPLL_N_CNT_ODD_DIV_DUTY_EN  -node $node    $n_duty_tweak
 
			set_atom_node_info -key INT_IOPLL_C_CNT_0_HI_DIV          -node $node    $c0_hi_div
			set_atom_node_info -key INT_IOPLL_C_CNT_0_LO_DIV          -node $node    $c0_lo_div
			set_atom_node_info -key BOOL_IOPLL_C_CNT_0_BYPASS_EN      -node $node    $c0_bypass
			set_atom_node_info -key BOOL_IOPLL_C_CNT_0_EVEN_DUTY_EN   -node $node    $c0_duty_tweak
 
			set_atom_node_info -key INT_IOPLL_C_CNT_1_HI_DIV          -node $node    $c1_hi_div
			set_atom_node_info -key INT_IOPLL_C_CNT_1_LO_DIV          -node $node    $c1_lo_div
			set_atom_node_info -key BOOL_IOPLL_C_CNT_1_BYPASS_EN      -node $node    $c1_bypass
			set_atom_node_info -key BOOL_IOPLL_C_CNT_1_EVEN_DUTY_EN   -node $node    $c1_duty_tweak
 
			set_atom_node_info -key ENUM_IOPLL_PLL_BWCTRL             -node $node    $mif_pll_bwctrl_old
			set_atom_node_info -key ENUM_IOPLL_PLL_CP_CURRENT         -node $node    $mif_pll_cp_current_old
			}
 
		if { $device_family == "Stratix 10"} {
			set_atom_node_info -key ENUM_IOPLL_PLL_RIPPLECAP_CTRL     -node $node    $mif_pll_ripplecap_old
		}
 
	}
 
  # Success!
  return TCL_OK
}

proc round_to_atom_precision { value } {
 
  # Round to 6 decimal points
  set n 6
  set rounded_num [format "%.${n}f" $value]
  set double_version [expr {double($rounded_num)} ]
 
  if {[string length $double_version] <= [string length $rounded_num]} {
    return $double_version
  } else  {
    return $rounded_num
  }
}
 
 
proc list_plls_in_design { } {
  post_message "Found the following IOPLLs in design:"
  foreach_in_collection node [get_atom_nodes -type IOPLL] {
    set name [get_atom_node_info -key NAME -node $node]
    post_message "   $name"
  }
}
 
 
proc find_kernel_pll_in_design {pll_search_string} {
  foreach_in_collection node [get_atom_nodes -type IOPLL] {
    set node_name [ get_atom_node_info -key NAME -node $node]
    set name [get_atom_node_info -key NAME -node $node]
    if { [ string match $pll_search_string $node_name ] == 1} {
      post_message "Found kernel_pll: $node_name"
      set kernel_pll_name $node_name
      return $kernel_pll_name
    }
  }
}
 
# Return values: [retval panel_id row_index]
#   panel_id and row_index are only valid if the query is successful
# retval:
#    0: success
#   -1: not found
#   -2: panel not found (could be report not loaded)
#   -3: no rows found in panel
#   -4: multiple matches found
proc find_report_panel_row { panel_name col_index string_op string_pattern } {
    if {[catch {get_report_panel_id $panel_name} panel_id] || $panel_id == -1} {
        return -2;
    }
 
    if {[catch {get_number_of_rows -id $panel_id} num_rows] || $num_rows == -1} {
        return -3;
    }
 
    # Search for row match.
    set found 0
    set row_index -1;
 
    for {set r 1} {$r < $num_rows} {incr r} {
        if {[catch {get_report_panel_data -id $panel_id -row $r -col $col_index} value] == 0} {
            if {[string $string_op $string_pattern $value]} {
                if {$found == 0} {
                    # If multiple rows match, return the first
                    set row_index $r
                }
                incr found
            }
 
        }
    }
 
    if {$found > 1} {return [list -4 $panel_id $row_index]}
    if {$row_index == -1} {return -1}
 
    return [list 0 $panel_id $row_index]
}

# get_fmax_from_report: Determines the fmax for the given clock. The fmax value returned
# will meet all timing requirements (setup, hold, recovery, removal, minimum pulse width)
# across all corners.  The return value is a 2-element list consisting of the
# fmax and clk name
proc get_fmax_from_report { clkname required recovery_multicycle iteration } {
    global fast_compile
    global revision_name
    global unused_clk_fmax
    # Find the clock period.
    set result [list]
    if {$fast_compile} {
      set result [fetch_clock "$revision_name.fit.rpt" $clkname]
    } else {
      set result [find_report_panel_row "*Timing Analyzer||Clocks" 0 match $clkname]
    }
    set retval [lindex $result 0]
 
    if {$retval == -1} {
        if {$required == 1} {
           error "Error: Could not find clock: $clkname"
        } else {
           post_message -type warning "Could not find clock: $clkname.  Clock is not required assuming 10 GHz and proceeding."
           return [list $unused_clk_fmax $clkname]
        }
    } elseif {$retval < 0} {
        error "Error: Failed search for clock $clkname (error $retval)"
    }
 
    # Update clock name to full clock name ($clkname as passed in may contain wildcards).
    if {$fast_compile} {
      set clkname [lindex $result 0]
      set clk_period [lindex $result 1]
    } else {
      set panel_id [lindex $result 1]
      set row_index [lindex $result 2]
      set clkname [get_report_panel_data -id $panel_id -row $row_index -col 0]
      set clk_period [get_report_panel_data -id $panel_id -row $row_index -col 2]
    }
 
    post_message "Clock $clkname"
    post_message "  Period: $clk_period"
 
    # Determine the most negative slack across all relevant timing metrics (setup, recovery, minimum pulse width)
    # and across all timing corners. Hold and removal metrics are not taken into account
    # because their slack values are independent on the clock period (for kernel clocks at least).
    #
    # Paths that involve both a posedge and negedge of the kernel clocks are not handled properly (slack
    # adjustment needs to be doubled).
    if {!$fast_compile} {
      set timing_metrics [list "Setup" "Recovery" "Minimum Pulse Width"]
      set timing_metric_colindex [list 1 3 5 ]
      set timing_metric_required [list 1 0 0]
      set wc_slack $clk_period
      set has_slack 0
      set fmax_from_summary 5000.0
 
      set panel_name "*Timing Analyzer||Multicorner Timing Analysis Summary"
      set panel_id [get_report_panel_id $panel_name]
      set result [find_report_panel_row $panel_name 0 equal " $clkname"]
      set retval [lindex $result 0]
      set single off
      if {$retval == -2} {
        post_message -type critical_warning "Multicorner Analysis is off. No analysis has been done for other corners!"
        set single on
      }
 
      # Find the "Fmax Summary" numbers reported in Quartus.  This may not
      # account for clock transfers but it does account for pos-to-neg edge same
      # clock transfers.  Whatever we calculate should be less than this.
      set fmax_panel_name UNKNOWN
      if {[string match $single "off"]} {
        set fmax_panel_name "*Timing Analyzer||* Model||*Fmax Summary"
      } else {
        set fmax_panel_name "*Timing Analyzer||Fmax Summary"
      }
      foreach panel_name [get_report_panel_names] {
        if {[string match $fmax_panel_name $panel_name] == 1} {
          set result [find_report_panel_row $panel_name 2 equal $clkname]
          set retval [lindex $result 0]
          if {$retval == 0} {
            set restricted_fmax_field [get_report_panel_data -id [lindex $result 1] -row [lindex $result 2] -col 1]
            regexp {([0-9\.]+)} $restricted_fmax_field restricted_fmax
            if {$restricted_fmax < $fmax_from_summary} {
              set fmax_from_summary $restricted_fmax
            }
          }
        }
      }
      post_message "  Restricted Fmax from STA: $fmax_from_summary"
 
      # Find the worst case slack across all corners and metrics
      foreach metric $timing_metrics metric_required $timing_metric_required col_ndx $timing_metric_colindex {
        if {[string match $single "on"]} {
          set panel_name "*Timing Analyzer||$metric Summary"
          set result [find_report_panel_row $panel_name 0 equal "$clkname"]
          set col_ndx 1
        } else {
          set panel_name "*Timing Analyzer||Multicorner Timing Analysis Summary"
          set result [find_report_panel_row $panel_name 0 equal " $clkname"]
          set single off
        }
        set panel_id [get_report_panel_id $panel_name]
        set retval [lindex $result 0]
 
        if {$retval == -1} {
          if {$required == 1 && $metric_required == 1} {
            error "Error: Could not find clock: $clkname"
          }
        } elseif {$retval < 0 && $retval != -4 } {
          error "Error: Failed search for clock $clkname (error $retval)"
        }
 
        if {$retval == 0 || $retval == -4} {
          set slack [get_report_panel_data -id [lindex $result 1] -row [lindex $result 2] -col $col_ndx ]
          post_message "    $metric slack: $slack"
          if {$slack != "N/A"} {
            if {$metric == "Setup" || $metric == "Recovery"} {
              set has_slack 1
              if {$metric == "Recovery"} {
              set normalized_slack [ expr $slack / $recovery_multicycle ]
                post_message "    normalized $metric slack: $normalized_slack"
                set slack $normalized_slack
              }
            }
          }
          # Keep track of the most negative slack.
          if {$slack < $wc_slack} {
            set wc_slack $slack
            set wc_metric $metric
          }
        }
      }
    } else {
      post_message -type critical_warning "Fast-compile enabled. Parsing results based on Fitter timing models."
      set timing_metrics [list "setup" "recovery" "minimum pulse width"]
      set timing_metric_required [list 1 0 0]
      set wc_slack $clk_period
      set has_slack 0
      set fmax_from_summary 5000.0
 
      # Find the worst case slack across all corners and metrics
      foreach metric $timing_metrics metric_required $timing_metric_required {
        # will fail if clock is not found
        set slack [fetch_timing "$revision_name.fit.rpt" $metric $clkname $required]
 
        post_message "    $metric slack: $slack"
        if {$slack != "N/A"} {
          if {$metric == "setup" || $metric == "recovery"} {
            set has_slack 1
            if {$metric == "recovery"} {
            set normalized_slack [ expr $slack / $recovery_multicycle ]
              post_message "    normalized $metric slack: $normalized_slack"
              set slack $normalized_slack
            }
          }
          # Keep track of the most negative slack.
          if {$slack < $wc_slack} {
            set wc_slack $slack
            set wc_metric $metric
          }
        }
      }
 
    }
 
    if {$has_slack == 1} {
        # IOPLL jitter compensation convergence aid
        # for iterations 3, 4, 5 add 50ps, 100ps, 200ps of extra IOPLL period adjustment
        set jitter_compensation 0.0;
        if {$iteration > 2} {
          set jitter_compensation [expr 0.05*(2**($iteration-3))]
        }
 
        if {$fast_compile} {
          #jitter guardband for fast compile
          set jitter_compensation [expr 0.025]
          post_message "Fast compile added $jitter_compensation ns to clock period as jitter compensation"
        }
 
        # Adjust the clock period to meet the worst-case slack requirement.
        set clk_period [expr $clk_period - $wc_slack + $jitter_compensation]
        post_message "  Adjusted period: $clk_period ([format %+0.3f [expr -$wc_slack]], $wc_metric)"
 
        # Compute fmax from clock period. Clock period is in nanoseconds and the
        # fmax number should be in MHz.
        set fmax [expr 1000 / $clk_period]
 
        if {$fmax_from_summary < $fmax} {
            post_message "  Restricted Fmax from STA is lower than $fmax, using it instead."
            set fmax $fmax_from_summary
        }
 
        # Truncate to two decimal places. Truncate (not round to nearest) to avoid the
        # very small chance of going over the clock period when doing the computation.
        set fmax [expr floor($fmax * 100) / 100]
        post_message "  Fmax: $fmax"
    } else {
        post_message -type warning "No slack found for clock $clkname - assuming 10 GHz."
        set fmax $unused_clk_fmax
    }
 
    return [list $fmax $clkname]
}

# Returns [k_fmax fmax1 k_clk_name fmax2 k_clk2x_name]
proc get_kernel_clks_and_fmax { k_clk_name k_clk2x_name recovery_multicycle iteration} {
    set result [list]
    # Read in the achieved fmax
    post_message "Calculating maximum fmax..."
    set x [ get_fmax_from_report $k_clk_name 1 $recovery_multicycle $iteration]
    set fmax1 [ lindex $x 0 ]
    set k_clk_name [ lindex $x 1 ]
    set x [ get_fmax_from_report $k_clk2x_name 0 $recovery_multicycle $iteration]
    set fmax2 [ lindex $x 0 ]
    set k_clk2x_name [ lindex $x 1 ]
 
    # The maximum is determined by both the kernel-clock and the double-pumped clock
    set k_fmax $fmax1
    if { [expr 2 * $fmax1] > $fmax2 } {
       set k_fmax [expr $fmax2 / 2.0]
    }
    return [list $k_fmax $fmax1 $k_clk_name $fmax2 $k_clk2x_name]
}
 
##############################################################################
##############################       MAIN        #############################
##############################################################################

set num_expected_args 2
set num_expected_file_args 2
set prog "generate_pll_settings.tcl"

set num_files 0
set file_sizes [list]
set files [list]

if { $argc != $num_expected_args } {
   post_message "$prog: Need exactly two arguments: a reference frequency and a target frequency"
   exit 2
}

set refclk [ lindex $argv 0 ]
set k_fmax [ lindex $argv 1 ]

set speedgrade 2

post_message "Kernel Fmax determined to be $k_fmax MHz";
post_message "Using IOPLL reference frequency of $refclk MHz";

set actual_kernel_clk [get_nearest_achievable_frequency $k_fmax $refclk "Agilex" $speedgrade 2]
post_message "Desired kernel_clk frequency:"
post_message "  $k_fmax MHz"
post_message "Actual kernel_clk frequency:"
post_message "  $actual_kernel_clk MHz"

# Do changes for current revision (either base or import revision)
set success [adjust_iopll_frequency_in_postfit_netlist "Agilex" $speedgrade $refclk $actual_kernel_clk 0]
