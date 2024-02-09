// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: MIT

// Description
//-----------------------------------------------------------------------------
//
// GPIO Interface between HPS and Copy Engine
//
//-----------------------------------------------------------------------------

interface hps_ce_gpio_if;


    logic [1:0]         ssbl_vfy_gpio    ;
    logic [1:0]         kernel_vfy_gpio  ;
    logic               hps_rdy_gpio     ;
    logic               img_xfr_done_gpio;

    modport source (
        output   ssbl_vfy_gpio     ,
        output   kernel_vfy_gpio   ,
        output   hps_rdy_gpio      ,
        input    img_xfr_done_gpio
    );

    modport sink (
        input   ssbl_vfy_gpio      ,
        input   kernel_vfy_gpio    ,
        input   hps_rdy_gpio       ,    
        output  img_xfr_done_gpio
    );
 

endinterface : hps_ce_gpio_if

