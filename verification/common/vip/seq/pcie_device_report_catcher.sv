//=======================================================================
// COPYRIGHT (C) 2013 SYNOPSYS INC.
// This software and the associated documentation are confidential and
// proprietary to Synopsys, Inc. Your use or disclosure of this software
// is subject to the terms and conditions of a written license agreement
// between you, or your company, and Synopsys, Inc. In the event of
// publications, the following notice is applicable:
//
// ALL RIGHTS RESERVED
//
// The entire notice above must be reproduced on all authorized copies.
//-----------------------------------------------------------------------

`ifndef GEN_GUARD_SVT_PCIE_DEVICE_REPORT_CATCHER_SV
`define GEN_GUARD_SVT_PCIE_DEVICE_REPORT_CATCHER_SV


/**
 * Abstract:
 * This file test runs the default base test without modification
 */

class recovery_idle_catcher extends uvm_report_catcher;

   function new(string name="recovery_idle_catcher");
      super.new();
   endfunction

   function pattern_match(string str1, str2);
      int l1, l2;
      l1 = str1.len();
      l2 = str2.len();
      pattern_match = 0;
      if(l2 > l1) begin
         return 0;
      end
      for(int i = 0; i < l1-l2+1;i++) begin
         if(str1.substr(i, i+l2-1) == str2) begin
            return 1;
         end
      end
   endfunction

   virtual function action_e catch();
      if(get_severity()==UVM_ERROR) begin
         if((pattern_match(get_message(), "Lost valid signal level on receiver")))begin
            set_severity(UVM_INFO);
         end
      end
      return THROW;
   endfunction
endclass : recovery_idle_catcher

`endif // GEN_GUARD_SVT_PCIE_DEVICE_REPORT_CATCHER_SV

