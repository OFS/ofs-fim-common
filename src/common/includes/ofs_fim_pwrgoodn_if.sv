// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// Power Good Reset Interface.
//
// Definition of power-on reset signal interface.  This was done to create 
// virtual interfaces to be used with test class interfaces in simulation.  
// Used in synthesis for compatibility with simulation.
//
//-----------------------------------------------------------------------------

`ifndef __OFS_FIM_PWRGOODN_IF_SV__
`define __OFS_FIM_PWRGOODN_IF_SV__

interface ofs_fim_pwrgoodn_if; 
   logic pwr_good_n;
   
   modport master (
      output pwr_good_n
   );
   
   modport slave (
      input  pwr_good_n
   );

endinterface : ofs_fim_pwrgoodn_if 
`endif // __OFS_FIM_PWRGOODN_IF_SV__
