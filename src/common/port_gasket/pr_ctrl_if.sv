// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
// PR Controller Interface.
//-----------------------------------------------------------------------------

`ifndef __PG_PR_CTRL_IF_SV__
`define __PG_PR_CTRL_IF_SV__

interface pr_ctrl_if #(
   parameter CSR_REG_WIDTH = 64
);

//-----------------------------------------------------------------------------
//   Register Value Inputs 
//-----------------------------------------------------------------------------
   logic [CSR_REG_WIDTH-1:0]   inp2prc_pg_pr_ctrl;
   logic [CSR_REG_WIDTH-1:0]   inp2prc_pg_pr_status;
   logic [CSR_REG_WIDTH-1:0]   inp2prc_pg_pr_error;
   logic [CSR_REG_WIDTH-1:0]   inp2prc_pg_error;

//-----------------------------------------------------------------------------
//   Register Value Outputs 
//-----------------------------------------------------------------------------
   logic [CSR_REG_WIDTH-1:0]   prc2out_pg_pr_ctrl;
   logic [CSR_REG_WIDTH-1:0]   prc2out_pg_pr_status;
   logic [CSR_REG_WIDTH-1:0]   prc2out_pg_pr_data;
   logic                       prc2out_pg_pr_data_v;


   modport src (
      output  prc2out_pg_pr_ctrl,
      output  prc2out_pg_pr_status,
      output  prc2out_pg_pr_data,
      output  prc2out_pg_pr_data_v,

      input   inp2prc_pg_pr_ctrl,
      input   inp2prc_pg_pr_status,
      input   inp2prc_pg_pr_error,
      input   inp2prc_pg_error
   );

   modport snk (
      input   prc2out_pg_pr_ctrl,
      input   prc2out_pg_pr_status,
      input   prc2out_pg_pr_data,
      input   prc2out_pg_pr_data_v,

      output  inp2prc_pg_pr_ctrl,
      output  inp2prc_pg_pr_status,
      output  inp2prc_pg_pr_error,
      output  inp2prc_pg_error
   );

endinterface : pr_ctrl_if 
`endif // __PG_PR_CTRL_IF_SV__
