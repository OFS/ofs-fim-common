// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


//-------------------------------------
// Configurable number of pipe stages
//-------------------------------------
module pipe #(parameter W=1, N=2) (
  input var logic          clk,
  input var logic [W-1:0]  dIn,

  output logic [W-1:0] dOut
);

logic [W-1:0]   pipeT[N];

always @ (posedge clk) begin
  for (int i=0; i < N; i++) begin
    pipeT[i] <= (i == 0) ? dIn : pipeT[i-1];
  end
end

assign dOut = pipeT[N-1];

endmodule

