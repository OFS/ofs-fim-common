// Copyright 2001-2023 Intel Corporation
// SPDX-License-Identifier: MIT


`timescale 1 ps / 1 ps

// DESCRIPTION
//
// This is a small register circuit for synchronizing aclr signals to produce asynchronous attack and
// synchronous release across clock domains.
//



// CONFIDENCE
// This component has significant hardware test coverage in reference designs and Altera IP cores.
//

module eth_f_reset_synchronizer (
    input   aclr, // no domain
    input   clk,
    output  aclr_sync
);

wire aclr_sync_n;

    eth_f_altera_std_synchronizer_nocut #(
                    .depth(3),
                    .rst_value(1'b0)
         )  synchronizer_nocut_inst  (
                    .clk(clk),
                    .reset_n(!aclr),
                    .din(1'b1),
                    .dout(aclr_sync_n)
    );

assign aclr_sync = ~aclr_sync_n;

endmodule
