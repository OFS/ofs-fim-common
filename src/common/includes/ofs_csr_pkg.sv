// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// OFS CSR Package   .
//
// Definition of base CSR data structures and supporting types/parameters.
// Also included are the register update functions that support the per-bit 
// register attributes.
//
//-----------------------------------------------------------------------------

`ifndef __OFS_CSR_PKG__
`define __OFS_CSR_PKG__

package ofs_csr_pkg; 

//---------------------------------------------------------
// Parameter and Enum Definitions for CSRs.
//---------------------------------------------------------
parameter CSR_REG_WIDTH  = 64;
parameter CSR_ADDR_WIDTH = 20;
parameter CSR_FEATURE_RANGE = 32;
parameter CSR_FEATURE_NUM = 16;


//---------------------------------------------------------
// Register Bit Attributes.
//---------------------------------------------------------
typedef enum logic [3:0] {
   RO    = 4'h0, // Read-Only
   RW    = 4'h1, // Read-Write
   RWS   = 4'h2, // Read-Write Sticky Across Soft Reset
   RWD   = 4'h3, // Read-Write Sticky Across Hard Reset
   RW1C  = 4'h4, // Read-Write 1 to Clear
   RW1CS = 4'h5, // Read-Write 1 to Clear Sticky Across Soft Reset
   RW1CD = 4'h6, // Read-Write 1 to Clear Sticky Across Hard Reset
   RW1S  = 4'h7, // Read-Write 1 to Set
   RW1SS = 4'h8, // Read-Write 1 to Set Sticky Across Soft Reset
   RW1SD = 4'h9, // Read-Write 1 to Set Sticky Across Hard Reset
   Rsvd  = 4'hA, // Reserved - Don't Care
   RsvdP = 4'hB, // Reserved and Protected (SW read-modify-write)
   RsvdZ = 4'hC   // Reserved and Zero
} csr_bit_attr_t;

//---------------------------------------------------------
// CSR Access Type Size
//---------------------------------------------------------
typedef enum logic [1:0] {
   NONE    = 2'b00,
   LOWER32 = 2'b01,
   UPPER32 = 2'b10,
   FULL64  = 2'b11
} csr_access_type_t;


//---------------------------------------------------------
// Structures for CSR Registers.
//---------------------------------------------------------
// Generic type for accessing upper and lower 32-bits in 
// CSR registers.
//---------------------------------------------------------
typedef struct packed {
   logic[31:0] upper32;
   logic[31:0] lower32;
} ofs_csr_reg_2x32_t;
localparam REG_2x32_WIDTH = $bits(ofs_csr_reg_2x32_t);

typedef struct packed {
   csr_bit_attr_t [31:0] upper32;
   csr_bit_attr_t [31:0] lower32;
} ofs_csr_reg_2x32_attr_t;
localparam REG_2x32_ATTR_WIDTH = $bits(ofs_csr_reg_2x32_attr_t);


//---------------------------------------------------------
// Generic type for accessing upper and lower 32-bits in 
// CSR register as well as all 64-bits using union.
//---------------------------------------------------------
typedef union packed {
   ofs_csr_reg_2x32_t word;
   logic [63:0] data;
} ofs_csr_reg_generic_t;
localparam REG_GENERIC_WIDTH = $bits(ofs_csr_reg_generic_t);

typedef union packed {
   ofs_csr_reg_2x32_attr_t word;
   csr_bit_attr_t [63:0] data;
} ofs_csr_reg_generic_attr_t;
localparam REG_GENERIC_ATTR_WIDTH = $bits(ofs_csr_reg_generic_attr_t);


//---------------------------------------------------------
// Generic write transaction description to pass to CSR  
// "update_reg" function.  This should be decoded in the 
// calling module's local logic.
//---------------------------------------------------------
typedef struct packed {
   logic reset_n;
   logic pwr_good_n;
   ofs_csr_reg_generic_t wr_data;
   csr_access_type_t write_type;
} ofs_csr_hw_state_t;
localparam REG_HW_STATE_WIDTH = $bits(ofs_csr_hw_state_t);


//---------------------------------------------------------
// Generic register update function for CSR register with 
// update attributes for each bit.
//---------------------------------------------------------
function automatic logic[63:0] update_reg (     // Returns a 64-bit register.
   input csr_bit_attr_t [63:0] attr,            // Array of attributes for each bit in register.
   input logic          [63:0] reg_reset_val,   // Value loaded into register upon reset (depends on bit attributes).
   input logic          [63:0] reg_update_val,  // Value loaded into status registers upon every clock (monitor/clocked value).
   input logic          [63:0] reg_current_val, // Current stored value in register. Must be passed due to scoping rules.
   input logic                 write,           // Register write strobe.
   input ofs_csr_hw_state_t   state             // Hardware state in logic scope.  (See structure above.)
);
   integer i;
   for(i=0; i<CSR_REG_WIDTH; i=i+1)
   begin: set_attr 
      case (attr[i])

         // ------- READ-ONLY, updated by HW. ------
         RO: begin
            update_reg[i] = reg_update_val[i];
         end

         // ------- READ-WRITE -------
         RW: begin
            if(!state.reset_n)
               update_reg[i] = reg_reset_val[i];
            else
            begin
               // Updated by SW
               if (write)
               begin
                  // 64b access
                  if (state.write_type == FULL64)
                     update_reg[i] = state.wr_data.data[i];
                  else
                  // 32b access
                  begin
                     if (state.write_type == UPPER32)
                     begin
                        // update 32 MSBs
                        if (i >= CSR_REG_WIDTH/2)
                           update_reg[i] = state.wr_data.data[i];
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                     else
                     begin
                        // update 32 LSBs
                        if (i < CSR_REG_WIDTH/2)
                           update_reg[i] = state.wr_data.data[i];
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                  end
               end
               else
               begin
                  update_reg[i] = reg_current_val[i];
               end
            end
         end

         // ------- READ-WRITE Sticky Across Soft Reset-------
         RWS: begin
            if(!state.pwr_good_n)
               update_reg[i] = reg_reset_val[i];
            else
            begin
               // Updated by SW
               if (write)
               begin
                  // 64b access
                  if (state.write_type == FULL64)
                     update_reg[i] = state.wr_data.data[i];
                  else
                  // 32b access
                  begin
                     if (state.write_type == UPPER32)
                     begin
                        // update 32 MSBs
                        if (i >= CSR_REG_WIDTH/2)
                           update_reg[i] = state.wr_data.data[i];
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                     else
                     begin
                        // update 32 LSBs
                        if (i < CSR_REG_WIDTH/2)
                           update_reg[i] = state.wr_data.data[i];
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                  end
               end
               else
               begin
                  update_reg[i] = reg_current_val[i];
               end
            end
         end

         // ------- READ-WRITE Sticky Across Hard Reset-------
         RWD: begin
            // Updated by SW -- not by any reset, only power-on.
            if (write)
            begin
               // 64b access
               if (state.write_type == FULL64)
                  update_reg[i] = state.wr_data.data[i];
               else
               // 32b access
               begin
                  if (state.write_type == UPPER32)
                  begin
                     // update 32 MSBs
                     if (i >= CSR_REG_WIDTH/2)
                        update_reg[i] = state.wr_data.data[i];
                     else
                        update_reg[i] = reg_current_val[i];
                  end
                  else
                  begin
                     // update 32 LSBs
                     if (i < CSR_REG_WIDTH/2)
                        update_reg[i] = state.wr_data.data[i];
                     else
                        update_reg[i] = reg_current_val[i];
                  end
               end
            end
            else
            begin
               update_reg[i] = reg_current_val[i];
            end
         end

         // ------- READ / WRITE 1 TO CLEAR -------
         RW1C: begin
            if(!state.reset_n)
               update_reg[i] = reg_reset_val[i];
            else
            begin
               // Clear when SW writes 1
               if (write)
               begin
                  // 64b access
                  if ((state.write_type == FULL64) && (state.wr_data.data[i] == 1'b1))
                     update_reg[i] = 1'b0;
                  else
                  // 32b access
                  begin
                     if (state.write_type == UPPER32)
                     begin
                        // update 32 MSBs
                        if ((i >= CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                           update_reg[i] = 1'b0;
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                     else
                     begin
                        // update 32 LSBs
                        if ((i < CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                           update_reg[i] = 1'b0;
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                  end    
               end
               else
               begin
                  // HW updates (set) only for active-high level
                  if (reg_update_val[i])
                     update_reg[i] = 1'b1; 
                  else
                     update_reg[i] = reg_current_val[i];
               end
            end
         end

         // ------- READ / WRITE 1 TO CLEAR Sticky Across Soft Reset -------
         RW1CS: begin
            if(!state.pwr_good_n)
               update_reg[i] = reg_reset_val[i];
            else
            begin
               // Clear when SW writes 1
               if (write)
               begin
                  // 64b access
                  if ((state.write_type == FULL64) && (state.wr_data.data[i] == 1'b1))
                     update_reg[i] = 1'b0;
                  else
                  // 32b access
                  begin
                     if (state.write_type == UPPER32)
                     begin
                        // update 32 MSBs
                        if ((i >= CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                           update_reg[i] = 1'b0;
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                     else
                     begin
                        // update 32 LSBs
                        if ((i < CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                           update_reg[i] = 1'b0;
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                  end    
               end
               else
               begin
                  // HW updates (set) only for active-high level
                  if (reg_update_val[i])
                     update_reg[i] = 1'b1;
                  else
                     update_reg[i] = reg_current_val[i];
               end
            end
         end

         // ------- READ / WRITE 1 TO CLEAR Sticky Across Hard Reset -------
         RW1CD: begin
            // Clear when SW writes 1
            if (write)
            begin
               // 64b access
               if ((state.write_type == FULL64) && (state.wr_data.data[i] == 1'b1))
                  update_reg[i] = 1'b0;
               else
               // 32b access
               begin
                  if (state.write_type == UPPER32)
                  begin
                     // update 32 MSBs
                     if ((i >= CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                        update_reg[i] = 1'b0;
                     else
                        update_reg[i] = reg_current_val[i];
                  end
                  else
                  begin
                     // update 32 LSBs
                     if ((i < CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                        update_reg[i] = 1'b0;
                     else
                        update_reg[i] = reg_current_val[i];
                  end
               end    
            end
            else
            begin
               // HW updates (set) only for active-high level
               if (reg_update_val[i])
                  update_reg[i] = 1'b1; 
               else
                  update_reg[i] = reg_current_val[i];
            end
         end

         // ------- READ / WRITE 1 TO SET -------
         RW1S: begin
            if(!state.reset_n)
               update_reg[i] = reg_reset_val[i];
            else
            begin
               // Set when SW writes 1
               if (write)
               begin
                  // 64b access
                  if ((state.write_type == FULL64) && (state.wr_data.data[i] == 1'b1))
                     update_reg[i] = 1'b1;
                  else
                  // 32b access
                  begin
                     if (state.write_type == UPPER32)
                     begin
                        // update 32 MSBs
                        if ((i >= CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                           update_reg[i] = 1'b1;
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                     else
                     begin
                        // update 32 LSBs
                        if ((i < CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                           update_reg[i] = 1'b1;
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                  end    
               end
               else
               begin
                  // HW updates (clear) only for active-high level
                  if (reg_update_val[i])
                     update_reg[i] = 1'b0;
                  else
                     update_reg[i] = reg_current_val[i];
               end
            end
         end

         // ------- READ / WRITE 1 TO SET Sticky Across Soft Reset. -------
         RW1SS: begin
            if(!state.pwr_good_n)
               update_reg[i] = reg_reset_val[i];
            else
            begin
               // Set when SW writes 1
               if (write)
               begin
                  // 64b access
                  if ((state.write_type == FULL64) && (state.wr_data.data[i] == 1'b1))
                     update_reg[i] = 1'b1;
                  else
                  // 32b access
                  begin
                     if (state.write_type == UPPER32)
                     begin
                        // update 32 MSBs
                        if ((i >= CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                           update_reg[i] = 1'b1;
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                     else
                     begin
                        // update 32 LSBs
                        if ((i < CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                           update_reg[i] = 1'b1;
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                  end    
               end
               else
               begin
                  // HW updates (clear) only for active-high level
                  if (reg_update_val[i])
                     update_reg[i] = 1'b0;
                  else
                     update_reg[i] = reg_current_val[i];
               end
            end
         end

         // ------- READ / WRITE 1 TO SET, Sticky Across Hard Reset. -------
         RW1SD: begin
            // Set when SW writes 1
            if (write)
            begin
               // 64b access
               if ((state.write_type == FULL64) && (state.wr_data.data[i] == 1'b1))
                  update_reg[i] = 1'b1;
               else
               // 32b access
               begin
                  if (state.write_type == UPPER32)
                  begin
                     // update 32 MSBs
                     if ((i >= CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                        update_reg[i] = 1'b1;
                     else
                        update_reg[i] = reg_current_val[i];
                  end
                  else
                  begin
                     // update 32 LSBs
                     if ((i < CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                        update_reg[i] = 1'b1;
                     else
                        update_reg[i] = reg_current_val[i];
                  end
               end    
            end
            else
            begin
               // HW updates (clear) only for active-high level
               if (reg_update_val[i])
                  update_reg[i] = 1'b0;
               else
                  update_reg[i] = reg_current_val[i];
            end
         end

         // ------- Reserved - Bits are "Don't Cares". -----
         Rsvd: begin
            update_reg[i] = 1'b0;
         end

         // ------- Reserved - Bits Must Be Preserved By SW RW. -------
         RsvdP: begin
            if(!state.reset_n)
               update_reg[i] = reg_reset_val[i];
            else
            begin
               // Updated by SW
               if (write)
               begin
                  // 64b access
                  if (state.write_type == FULL64)
                     update_reg[i] = state.wr_data.data[i];
                  else
                  // 32b access
                  begin
                     if (state.write_type == UPPER32)
                     begin
                        // update 32 MSBs
                        if (i >= CSR_REG_WIDTH/2)
                           update_reg[i] = state.wr_data.data[i];
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                     else
                     begin
                        // update 32 LSBs
                        if (i < CSR_REG_WIDTH/2)
                           update_reg[i] = state.wr_data.data[i];
                        else
                           update_reg[i] = reg_current_val[i];
                     end
                  end
               end
            end
         end

         // ------- Reserved - Read as Zero (RsvdZ) -------
         RsvdZ: begin
            update_reg[i] = 1'b0;
         end

      endcase 
   end: set_attr
   return update_reg;
endfunction


//---------------------------------------------------------
// Register update function for Error Status registers.
//---------------------------------------------------------
function automatic logic[63:0] update_error_reg (     // Returns a 64-bit register.
   input logic          [63:0] reg_mask_val,  // Interrupt Mask.  If Mask bit = 1'b1, Interrupt source will be blocked from creating new interrupts.
   input logic          [63:0] reg_reset_val,  // Value loaded into status registers upon hard reset.
   input logic          [63:0] reg_update_val,  // Value loaded into status registers upon every clock (monitor/clocked value).
   input logic          [63:0] reg_current_val, // Current stored value in register. Must be passed due to scoping rules.
   input logic                 write,
   input ofs_csr_hw_state_t    state
);
   integer i;
   for(i=0; i<CSR_REG_WIDTH; i=i+1)
   begin: set_error_bits
      if(!state.pwr_good_n)
         update_error_reg[i] = reg_reset_val[i];
      else
      begin
         // Clear when SW writes 1
         if (write)
         begin
            // 64b access
            if ((state.write_type == FULL64) && (state.wr_data.data[i] == 1'b1))
               update_error_reg[i] = 1'b0;
            else
            // 32b access
            begin
               if (state.write_type == UPPER32)
               begin
                  // update 32 MSBs
                  if ((i >= CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                     update_error_reg[i] = 1'b0;
                  else
                     update_error_reg[i] = reg_current_val[i];
               end
               else
               begin
                  // update 32 LSBs
                  if ((i < CSR_REG_WIDTH/2) && (state.wr_data.data[i] == 1'b1))
                     update_error_reg[i] = 1'b0;
                  else
                     update_error_reg[i] = reg_current_val[i];
               end
            end    
         end
         else
         begin
            // HW updates (set) only for active-high level and not masked with a 1'b1.
            if ((reg_mask_val[i] == 1'b0) && (reg_update_val[i] == 1'b1))
               update_error_reg[i] = 1'b1;
            else
               update_error_reg[i] = reg_current_val[i];
         end
      end
   end: set_error_bits
   return update_error_reg;
endfunction



endpackage: ofs_csr_pkg

`endif // __OFS_CSR_PKG__
