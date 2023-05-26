// Copyright 2021 Intel Corporation
// SPDX-License-Identifier: MIT

//`include "prio_enc_w12_t2.v"
//`include "prio_enc_w12_t2_b12.v"
//`include "prio_enc_w12_t2_b24.v"
//`include "prio_enc_w12_t2_b36.v"
//`include "prio_enc_w12_t2_b48.v"
//`include "prio_enc_w8_t2.v"

// Uses 8 12:4 pri_encoders generated using Gregg's script.
// Select lines to the mux use 8:3 pri encoder.

module pri_enc_96_7 #(
  parameter SIM_EMULATE = 1'b0
) (
  input  logic        clk,
  input  logic [95:0] din,
  output logic [6:0]  dout
);

  logic [3:0] p0_dout;
  logic [4:0] p1_dout;
  logic [5:0] p2_dout;
  logic [5:0] p3_dout;
  logic [5:0] p4_dout;
  logic [6:0] p5_dout;
  logic [6:0] p6_dout;
  logic [6:0] p7_dout;

  logic [7:0] sel;
  logic [3:0] sel_dout;
  
  logic [6:0] mux_dout;
  
  prio_enc_w12_t2 #(
      .SIM_EMULATE(SIM_EMULATE)
  ) p0 (
      .clk(clk),
      .din(din[11:0]),
      .dout(p0_dout)
  );
  
  prio_enc_w12_t2_b12 #(
      .SIM_EMULATE(SIM_EMULATE)
  ) p1 (
      .clk(clk),
      .din(din[23:12]),
      .dout(p1_dout)
  );
  
  prio_enc_w12_t2_b24 #(
      .SIM_EMULATE(SIM_EMULATE)
  ) p2 (
      .clk(clk),
      .din(din[35:24]),
      .dout(p2_dout)
  );
  
  prio_enc_w12_t2_b36 #(
      .SIM_EMULATE(SIM_EMULATE)
  ) p3 (
      .clk(clk),
      .din(din[47:36]),
      .dout(p3_dout)
  );
  
  prio_enc_w12_t2_b48 #(
      .SIM_EMULATE(SIM_EMULATE)
  ) p4 (
      .clk(clk),
      .din(din[59:48]),
      .dout(p4_dout)
  );
  
  prio_enc_w12_t2_b60 #(
      .SIM_EMULATE(SIM_EMULATE)
  ) p5 (
      .clk(clk),
      .din(din[71:60]),
      .dout(p5_dout)
  );

  prio_enc_w12_t2_b72 #(
      .SIM_EMULATE(SIM_EMULATE)
  ) p6 (
      .clk(clk),
      .din(din[83:72]),
      .dout(p6_dout)
  );

  prio_enc_w12_t2_b84 #(
      .SIM_EMULATE(SIM_EMULATE)
  ) p7 (
      .clk(clk),
      .din(din[95:84]),
      .dout(p7_dout)
  );

  assign sel[0] = |din[11:0];   
  assign sel[1] = |din[23:12];   
  assign sel[2] = |din[35:24];   
  assign sel[3] = |din[47:36];   
  assign sel[4] = |din[59:48];   
  assign sel[5] = |din[71:60];   
  assign sel[6] = |din[83:72];   
  assign sel[7] = |din[95:84];   

  prio_enc_w8_t2 #(
      .SIM_EMULATE(SIM_EMULATE)
  ) s0 (
      .clk(clk),
      .din(sel),
      .dout(sel_dout)
  );

  always_comb 
  begin
    mux_dout = 7'h00;
    case(sel_dout)
      4'h0:    mux_dout = {2'b00,p0_dout};
      4'h1:    mux_dout = {1'b0, p1_dout};
      4'h2:    mux_dout = p2_dout;
      4'h3:    mux_dout = p3_dout;
      4'h4:    mux_dout = p4_dout;
      4'h5:    mux_dout = p5_dout;
      4'h6:    mux_dout = p6_dout;
      4'h7:    mux_dout = p7_dout;
      default: mux_dout = 96;
    endcase
  end

  always @ (posedge clk)
  begin
    dout <= mux_dout;
  end

endmodule
