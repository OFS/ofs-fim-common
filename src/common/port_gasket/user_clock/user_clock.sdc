# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

# Description
#-----------------------------------------------------------------------------
#
#  User clock SDC 
#
#-----------------------------------------------------------------------------

# For input to a 2-FFs synchronizer chain within qph_user_clk module
set_false_path -from [get_registers {*|qph_user_clk|qph_user_clk_freq|prescaler[*]}]      -to [get_registers {*|qph_user_clk|qph_user_clk_freq|smpclk_meta}]
set_false_path -from [get_registers {*|qph_user_clk|qph_user_clk_freq|prescaler_div2[*]}] -to [get_registers {*|qph_user_clk|qph_user_clk_freq|smpclk_meta_div2}]
