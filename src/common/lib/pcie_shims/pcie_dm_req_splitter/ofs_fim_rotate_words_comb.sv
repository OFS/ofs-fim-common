// Copyright 2022 Intel Corporation
// SPDX-License-Identifier: MIT


//
// Combinational, variable rotate N words. The rotation is organized as
// a cascade of binary decisions, acting on each bit in the rotation count
// independently. The default multiplexing depth is log2(DATA_WIDTH / WORD_WIDTH),
// e.g. depth 4 for 512 bit data and 32 bit words.
//

module ofs_fim_rotate_words_comb
  #(
    parameter DATA_WIDTH = 512,
    parameter WORD_WIDTH = 32,
    // Maximum rotation count, defaulting to full rotation
    parameter MAX_ROTATION = DATA_WIDTH / WORD_WIDTH,
    parameter ROTATE_LEFT = 1		// Set to 0 for right rotation
    )
   (
    input  logic [DATA_WIDTH-1 : 0] d_in,
    input  logic [$clog2(MAX_ROTATION)-1 : 0] rot_cnt,
    output logic [DATA_WIDTH-1 : 0] d_out
    );

    localparam NUM_WORDS = DATA_WIDTH / WORD_WIDTH;
    localparam WORD_IDX_WIDTH = $clog2(MAX_ROTATION);

    typedef logic [NUM_WORDS-1:0][WORD_WIDTH-1:0] t_word_vec;

    // Incoming data to wv[WORD_IDX_WIDTH]. Outgoing rotated data on wv[0].
    t_word_vec wv[WORD_IDX_WIDTH + 1];
    assign d_out = wv[0];

    always_comb
    begin
        wv[WORD_IDX_WIDTH] = d_in;

        // For each bit in the rotation count (starting with the high one)
        for (int b = WORD_IDX_WIDTH-1, chunk = 0; b >= 0; b = b - 1)
        begin
            // Rotate chunks, sized corresponding to the selected bit.
            chunk = (1 << b);
            for (int i = 0; i < NUM_WORDS; i = i + 1)
            begin
                int rot_idx;
                if (ROTATE_LEFT)
                    rot_idx = (i-chunk >= 0) ? i-chunk : i-chunk+NUM_WORDS;
                else
                    rot_idx = (i+chunk < NUM_WORDS) ? i+chunk : i+chunk-NUM_WORDS;

                // Binary decision - When rotate count bit is 1, do the rotation.
                // When the bit is 0, keep the chunk in its current position.
                wv[b][i] = (rot_cnt[b] ? wv[b+1][rot_idx] : wv[b+1][i]);
            end
        end
    end

endmodule // ofs_fim_rotate_words_comb
