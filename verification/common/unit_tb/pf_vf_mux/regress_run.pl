#!/usr/bin/env perl
# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: MIT

use strict;
use warnings;

use MIME::Lite; 
use Net::SMTP;


my $OFS_ROOTDIR=`git rev-parse --show-toplevel`;
my $sanitytests = `echo \${OFS_ROOTDIR}/verification/common/pf_vf_mux/test_package.sv`;
my $testdir = ' ';
my $vcs_logfile = ' ';
my $test_runsim = ' ';
my $runsim = 'runsim.log';
my $vcslog = 'vcs.log';
my $sim = 'results';
my $platform = $ARGV[0];
my $term = $ARGV[1];
my $coverage = $ARGV[2];
my $scripts=`pwd`;
my $variant = 'PF_VF_MUX';
my $a = "FAILED"; 
my $b = "FAILED";
my $mail_testname = ' '; 
my $run_flag = 0;
my $run_flag_config_1 = 0;
my $run_flag_config_2 = 0;
my $run_flag_config_3 = 0;
my $run_pass = 0;
my $run_present = 0;
my $result = ' ';
my $seed;
my $data = "<table border='1'>";
my $count=0;
my $git_rev = `git log -n 1`;
my $run_config=0;
my $mail_config=0;
my @tests_to_run ;
chomp $scripts;
push(@tests_to_run,$sanitytests);

system("rm -rf results/ vip/");
system("gmake -f Makefile_VCS.mk build_vip");


foreach my $item(@tests_to_run)
{
    open(my $sh,  $item);
    while (my $test = <$sh>) {
    chomp $test;
    next if($test =~ m/`include "(pf_vf_mux_base_test).sv"/);
    if($test =~ m/`include "(pf_vf_mux_.*).sv"/)
    {
    print "$1\n";
      my $testpath = join('/',$sim,"$1",$runsim);
      $testdir = $1;
      if($platform eq "TB_CONFIG_1")    
  
      ################################## Running VCS for all testcases in single configs without coverage ############################
 
      { 
          if($term eq "ARC")
          {
              system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_1=1\"");
          }
          elsif($term eq "XTERM")
          {
              system("gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_1=1");   
          }
      }
      elsif($platform eq "TB_CONFIG_2")
      {
          if($term eq "ARC")
          {
              system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_2=1\"");
          }
          elsif($term eq "XTERM")
          {
              system("gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_2=1");
          }
      }
      elsif($platform eq "TB_CONFIG_3")
      {
          if($term eq "ARC")
          {
              system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_3=1\"");
          }
          elsif($term eq "XTERM")
          {
              system("gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_3=1");
          }
      }
      elsif($platform eq "TB_CONFIG_ALL") 

     ################################## Running VCS for all testcases in all configs with coverage ################################################

      {
        if(defined $coverage)
        {
          if($term eq "ARC")
          {
              if($testdir=~ m/((pf_vf_mux_master_bp.*)|(pf_vf_mux_slave_simultaneous_backpressure.*)|(pf_vf_mux_slave_sequential_backpressure.*)|(pf_vf_mux_slave_fifo.*)|(pf_vf_mux_master_fifo.*)|(pf_vf_mux_master_axi_write_invalid.*)|(pf_vf_mux_master_axi_reset.*)|(pf_vf_mux_tuser_vendor_toggle.*)|(pf_vf_mux_slave_axi_reset.*))/)
              {
                 system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_3=1 COV=1\"");
              }
              else
              {
                 system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_1=1 COV=1\"");
                 system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_2=1 COV=1\"");
                 system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_3=1 COV=1\"");
              }
           }
           elsif($term eq "XTERM")
           {
               if($testdir=~ m/((pf_vf_mux_master_bp.*)|(pf_vf_mux_slave_simultaneous_backpressure.*)|(pf_vf_mux_slave_sequential_backpressure.*)|(pf_vf_mux_slave_fifo.*)|(pf_vf_mux_master_fifo.*)|(pf_vf_mux_master_axi_write_invalid.*)|(pf_vf_mux_tuser_vendor_toggle.*)|(pf_vf_mux_master_axi_reset.*)|(pf_vf_mux_slave_axi_reset.*))/)
               {
                 system("gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_3=1 COV=1");
               }
               else
               {
                 system("gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_1=1 COV=1");
                 system("gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_2=1 COV=1");
                 system("gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_3=1 COV=1");
               }
           }
         }
         else                                

         ################################## Running VCS for all testcases in all configs without coverage ############################
        
        {
           if($term eq "ARC")
           {
               if($testdir=~ m/((pf_vf_mux_master_bp.*)|(pf_vf_mux_slave_simultaneous_backpressure.*)|(pf_vf_mux_slave_sequential_backpressure.*)|(pf_vf_mux_slave_fifo.*)|(pf_vf_mux_master_fifo.*)|(pf_vf_mux_master_axi_write_invalid.*)|(pf_vf_mux_tuser_vendor_toggle.*)|(pf_vf_mux_master_axi_reset.*)|(pf_vf_mux_slave_axi_reset.*))/)
               {
                 system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_3=1\"");
               }
               else
               {
                 system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_1=1\"");
                 system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_2=1\"");
                 system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_3=1\"");
               }
           }
           elsif($term eq "XTERM")
           {
               if($testdir=~ m/((pf_vf_mux_master_bp.*)|(pf_vf_mux_slave_simultaneous_backpressure.*)|(pf_vf_mux_slave_sequential_backpressure.*)|(pf_vf_mux_slave_fifo.*)|(pf_vf_mux_master_fifo.*)|(pf_vf_mux_tuser_vendor_toggle.*)|(pf_vf_mux_master_axi_write_invalid.*)|(pf_vf_mux_master_axi_reset.*)|(pf_vf_mux_slave_axi_reset.*))/)
               {
                 system("gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_3=1");
               }
               else
               {
                 system("gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_1=1");
                 system("gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_2=1");
                 system("gmake -f Makefile_VCS.mk vcs TESTNAME=$testdir TB_CONFIG_3=1");
               }
            }       
          }
       }

     ############################## Processing vcs logfiles of all testcases for single configs ##############################################

      if($platform eq "TB_CONFIG_1")
       { $vcs_logfile = join('/',$sim,"$1_CONFIG_1",$vcslog); }
      elsif($platform eq "TB_CONFIG_2")
       { $vcs_logfile = join('/',$sim,"$1_CONFIG_2",$vcslog); }
      elsif($platform eq "TB_CONFIG_3")
       { $vcs_logfile = join('/',$sim,"$1_CONFIG_3",$vcslog); }

     if ($platform ne "TB_CONFIG_ALL")
         {
         while (1)
         {
            if (-e $vcs_logfile) 
            {print "vcs.log is created\n"; last; }
         }
         open(my $fh,  $vcs_logfile)
         or die "Could not open file '$vcs_logfile' $!";
         
         while (1)
         { 
           while (my $row = <$fh>) 
           {
              chomp $row;
              if($row =~ m/CPU time.*seconds to compile.*seconds to elab.*seconds to link/)
              { print "$row\n"; $run_flag = 1;last;}
              elsif($row =~ m/Error-/)
              {$run_flag =2;}                       #------- $run_flag is used as an parameter to denote vcs pass or failed-------------#
           }                                        #------------------------ $run flag =1 denotes vcs passed --------------------------#
           if($run_flag == 1)                       #------------------------ $run flag =2 denotes vcs failed --------------------------#
           { last; }
           elsif($run_flag ==2)
           { print "VCS error in Testname = $testdir\n"; last;}
          }}

       ########################### Processing vcs logfiles of Error scenario testcases for all configs #########################################
    
      elsif($platform eq "TB_CONFIG_ALL"){
          if($testdir=~ m/((pf_vf_mux_master_bp.*)|(pf_vf_mux_slave_simultaneous_backpressure.*)|(pf_vf_mux_slave_sequential_backpressure.*)|(pf_vf_mux_slave_fifo.*)|(pf_vf_mux_master_fifo.*)|(pf_vf_mux_master_axi_write_invalid.*)|(pf_vf_mux_tuser_vendor_toggle.*)|(pf_vf_mux_master_axi_reset.*)|(pf_vf_mux_slave_axi_reset.*))/)
          {
             $run_config=3;                                                    #----------------- $run_config denotes the config in which testcase is running ----------------#
             $vcs_logfile = join('/',$sim,"$1_CONFIG_$run_config",$vcslog);
             while (1)
             {
               if (-e $vcs_logfile)
               {print "CONFIG_$run_config vcs.log is created\n"; last;}
             }

             open(my $fh,  $vcs_logfile);
             while (1) 
             { 
                while (my $row = <$fh>) 
                {
                  chomp $row;
                  if($row =~ m/CPU time.*seconds to compile.*seconds to elab.*seconds to link/)
                  { print "$row\n";$run_flag_config_3=1;last;}
                  elsif($row =~ m/Error-/)
                  {$run_flag_config_3=2;last;}
                 }
                 if($run_flag_config_3 ==1)
                 {last;} 
                 elsif($run_flag_config_3 ==2)
                 {print "VCS error in Testname = $vcs_logfile\n"; last;} 
              }
          }
    
       ################ Processing vcs logfiles of basic and complex scenario testcases for all configs #######################################

         else                                 
          {
            for ($run_config=1 ; $run_config<4 ; $run_config++)
            {
            $vcs_logfile = join('/',$sim,"$1_CONFIG_$run_config",$vcslog);
            while (1)
            {
               if (-e $vcs_logfile)
               {print "CONFIG_$run_config vcs.log is created\n";last; }
            }

            open(my $fh,  $vcs_logfile)
            or die "Could not open file '$vcs_logfile' $!";
            
            while (1) { 
            while (my $row = <$fh>) 
            {
                chomp $row;
                if($row =~ m/CPU time.*seconds to compile.*seconds to elab.*seconds to link/)
                   { print "$row\n";
                     if($run_config==1)                           #----------------- $run_config denotes the config in which testcase is running --------------------#
                     {$run_flag_config_1 = 1;}                    #------- $run_flag_N is used as an parameter to denote vcs pass or failed for config N-------------#
                     elsif($run_config==2)                         #---------$run_flag_N =1 denotes vcs passed ------- $run_flag_N=2 denotes vcs failed ------------#
                     {$run_flag_config_2 = 1;}
                     elsif($run_config==3)
                     {$run_flag_config_3 =1;}
                     last;
                    }
                elsif($row =~ m/Error-/)
                   {
                    if($run_config==1)
                    {$run_flag_config_1 = 2;}
                   elsif($run_config==2)
                    {$run_flag_config_2 = 2;}
                   elsif($run_config==3)
                    {$run_flag_config_3 =2;}
                    last;
                   }
             }
             if($run_config == 1) 
             {  if($run_flag_config_1 ==1)
                {last;} 
                elsif($run_flag_config_1 ==2)
                {print "VCS error in Testname = $vcs_logfile\n";last;}
             }
             if($run_config == 2) 
             {  if($run_flag_config_2 ==1)
                {last;} 
                elsif($run_flag_config_2 ==2)
                {print "VCS error in Testname = $vcs_logfile\n";last}
             }
             if($run_config == 3) 
             {  if($run_flag_config_3 ==1)
                {last;} 
                elsif($run_flag_config_3 ==2)
                { print "VCS error in Testname = $vcs_logfile\n"; last }
             }
           }
         }
       }            
     }         

        if($run_flag == 1)         
         {

          ####################################### Running single config testcases with coverage ##########################################################

           if(defined $coverage)
           {
              if($platform eq "TB_CONFIG_1")  
              {
                if($term eq "ARC")
                {
                    system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_1=1 COV=1\"");
                }
                elsif($term eq "XTERM")
                {
                    system("gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_1=1 COV=1");
                }
              }
              elsif($platform eq "TB_CONFIG_2") 
              {
                if($term eq "ARC")
                {
                    system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_2=1 COV=1\"");
                }
                elsif($term eq "XTERM")
                {
                    system("gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_2=1 COV=1");
                }
              }
              elsif($platform eq "TB_CONFIG_3") 
              {
                if($term eq "ARC")
                {
                    system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_3=1 COV=1\"");
                }
                elsif($term eq "XTERM")
                {
                    system("gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_3=1 COV=1");
                }
              }
              $run_flag = 0;
           }

          ###################################3## Running single config testcases without coverage ####################################################

          else
          {
             if($platform eq "TB_CONFIG_1") 
              {
                if($term eq "ARC")
                {
                    system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_1=1\"");
                }
                elsif($term eq "XTERM")
                {
                    system("gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_1=1");
                }
              }
             elsif($platform eq "TB_CONFIG_2") 
              {
                 if($term eq "ARC")
                 {
                     system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_2=1\"");
                 }
                 elsif($term eq "XTERM")
                 {
                     system("gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_2=1");
                 }
              }
             elsif($platform eq "TB_CONFIG_3")
              {
                 if($term eq "ARC")
                 {
                     system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_3=1\"");
                 }
                 elsif($term eq "XTERM")
                 {
                     system("gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_3=1");
                 }
              }
             $run_flag = 0;
          }
        }
 
        ################################################ Running all config testcases #################################################################

        if($run_flag_config_1==1)
        {
          if(defined $coverage)
          {
                if($term eq "ARC")
                {
                    system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_1=1 COV=1\"");
                }
                elsif($term eq "XTERM")
                {
                    system("gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_1=1 COV=1");
                }
           }
           else
              {
                if($term eq "ARC")
                {
                    system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_1=1\"");
                }
                elsif($term eq "XTERM")
                {
                    system("gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_1=1");
                }
              }
          $run_flag_config_1=0;      
        }
        if($run_flag_config_2==1)
        {
          if(defined $coverage)
          {
                if($term eq "ARC")
                {
                    system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_2=1 COV=1\"");
                }
                elsif($term eq "XTERM")
                {
                    system("gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_2=1 COV=1");
                }
           }
           else
              {
                if($term eq "ARC")
                {
                    system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_2=1\"");
                }
                elsif($term eq "XTERM")
                {
                    system("gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_2=1");
                }
              }
          $run_flag_config_2=0;      
        }
        if($run_flag_config_3==1)
        {
          if(defined $coverage)
          {
                if($term eq "ARC")
                {
                    system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_3=1 COV=1\"");
                }
                elsif($term eq "XTERM")
                {
                    system("gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_3=1 COV=1");
                }
           }
           else
              {
                if($term eq "ARC")
                {
                    system("arc submit -PE flow/sw/bigmem mem=20000 -- \" gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_3=1\"");
                }
                elsif($term eq "XTERM")
                {
                    system("gmake -f Makefile_VCS.mk run_test TESTNAME=$testdir TB_CONFIG_3=1");
                }
              }
          $run_flag_config_3=0;      
        }
     }
  }
close $sh;
}

foreach my $item(@tests_to_run)
{
open(my $sh1,  $item);
while (my $test = <$sh1>) {
chomp $test;
next if($test =~ m/`include "(pf_vf_mux_base_test).sv"/);

       ######################################## Processing Runsims of all testcases for single configs #############################################

if($test =~ m/`include "(pf_vf_mux_.*).sv"/)
  {
    print "$1\n";
    if($platform ne "TB_CONFIG_ALL"){
    if($platform eq "TB_CONFIG_1")
      { $test_runsim = join('/',$sim,"$1_CONFIG_1",$runsim); }
    elsif($platform eq "TB_CONFIG_2")
      { $test_runsim = join('/',$sim,"$1_CONFIG_2",$runsim); }
    elsif($platform eq "TB_CONFIG_3")
      { $test_runsim = join('/',$sim,"$1_CONFIG_3",$runsim); }
    $testdir = $1;

    while (1) 
    {
      if (-e $test_runsim)
      { print "runsim.log is created\n"; $run_present = 1; last; }
    }
    if($run_present ==1){
    open(my $rh,  $test_runsim);
    $run_pass=0;
         
    while (1)
    { 
       while (my $row = <$rh>)
       {
         chomp $row;
         if($row =~ m/CPU Time|Fatal: /)
         { print "$row\n"; $run_pass = 1; $row = <$rh>;}
       }
       if($run_pass == 1)                                           
       { last; }
    }
    close $rh;
}

           ###################################### Mailing process of all testcases for Single configs ##################################################

if($run_present == 1)
{
    open(my $ph,  $test_runsim)
    or die "Could not open file '$test_runsim' $!";

    print "Processing $test_runsim \n";
    $a = "FAILED";
    $b = "FAILED";

    while(my $row = <$ph>)
    {
      chomp $row;
        if($row =~ m/UVM_ERROR :    0/)
        { $a = "PASSED"; print "Found 0 UVM_ERROR in $test_runsim \n"; }

        if($row =~ m/UVM_FATAL :    0/  ) 
        { $b = "PASSED"; print "Found 0 UVM_FATAL in $test_runsim \n"; last; }

        if($row =~ m/NOTE: automatic random seed used:(\s*)(\d*)/)
        { $seed = $2; }
    }

    if($a eq "PASSED" && $b eq "PASSED")
    { $result = "PASSED"."\n"; }
    else 
    { $result = "FAILED"."\n"; }


    if($count == 0)
    { $data .= "<tr><td>Testcase Name</td><td>Seed value</td><td>Status</td></tr>"; $count++;}

    if($a eq "PASSED" && $b eq "PASSED")
    { $data .= "<tr><td>$testdir</td><td>$seed</td><td>$result</td></tr>"; }
    else
    { $data .= "<tr><td>$testdir</td><td>$seed</td><td><font size=\"3\" color=\"#FF0000\">$result</td></tr>"; }
    $run_present = 0;
  }
elsif($run_present ==0)
  { $data .= "<tr><td>$testdir</td><td>NA</td><td><font size=\"3\" color=\"#FF0000\">VCS ERROR</td></tr>"; }
}

       ################################ Processing runsim log files for Error scenarios for all configs ########################################

elsif($platform eq "TB_CONFIG_ALL")
{   
if($1=~ m/((pf_vf_mux_master_bp.*)|(pf_vf_mux_slave_simultaneous_backpressure.*)|(pf_vf_mux_slave_sequential_backpressure.*)|(pf_vf_mux_slave_fifo.*)|(pf_vf_mux_master_fifo.*)|(pf_vf_mux_master_axi_write_invalid.*)|(pf_vf_mux_tuser_vendor_toggle.*)|(pf_vf_mux_master_axi_reset.*)|(pf_vf_mux_slave_axi_reset.*))/)
{
    $mail_config=3;
    $test_runsim = join('/',$sim,"$1_CONFIG_$mail_config",$runsim);                     #--------------------- $mail_config denotes the testcase config used for result mail processing---------------#
    $testdir = $1;
 
    while (1)
    {
      if (-e $test_runsim)
      { print "runsim.log is created\n"; $run_present = 1; last;}
    }
    if($run_present ==1){
    open(my $rh,  $test_runsim);
    $run_pass=0;
         
    while (1)
    { 
        while (my $row = <$rh>) 
        {
        chomp $row;
        if($row =~ m/CPU Time|Fatal: /)
        { print "$row\n"; $run_pass = 1; $row = <$rh>;}
        }
      if($run_pass == 1)
      { last; }
     }
    close $rh;
}
 
        ################################ Mailing process for Error scenario testcases for all configs #############################################

if($run_present == 1)                  
  {
     open(my $ph,  $test_runsim)
     or die "Could not open file '$test_runsim' $!";
     print "Processing $test_runsim \n";
     $a = "FAILED";
     $b = "FAILED";

     while(my $row = <$ph>) 
     {
      chomp $row;
        if($row =~ m/UVM_ERROR :    0/)
        { $a = "PASSED"; print "Found 0 UVM_ERROR in $test_runsim \n"; }

        if($row =~ m/UVM_FATAL :    0/  ) 
        { $b = "PASSED"; print "Found 0 UVM_FATAL in $test_runsim \n"; last; }

        if($row =~ m/NOTE: automatic random seed used:(\s*)(\d*)/)
        { $seed = $2; }
     }

    if($a eq "PASSED" && $b eq "PASSED")
      { $result = "PASSED"."\n"; }
    else 
      { $result = "FAILED"."\n"; }

    if($count == 0) 
      { $data .= "<tr><td>Testcase Name</td><td>Seed value</td><td>Status</td></tr>"; $count++; }

    if($a eq "PASSED" && $b eq "PASSED")
      { $data .= "<tr><td>$testdir\_CONFIG_\ $mail_config</td><td>$seed</td><td>$result</td></tr>"; }
    else
      { $data .= "<tr><td>$testdir\_CONFIG_\ $mail_config</td><td>$seed</td><td><font size=\"3\" color=\"#FF0000\">$result</td></tr>"; }
    $run_present = 0;
  }
elsif($run_present ==0)
  { $data .= "<tr><td>$testdir</td><td>NA</td><td><font size=\"3\" color=\"#FF0000\">VCS ERROR</td></tr>"; }    
}

       ################################## Processing Runsim Logs for Basic and complex scenarios ############################################

else
{
    for (my $mail_config=1 ; $mail_config<4 ; $mail_config++){
    $test_runsim = join('/',$sim,"$1_CONFIG_$mail_config",$runsim);
    $testdir = $1;
 
    while (1)
    {
      if (-e $test_runsim)
      { print "runsim.log is created\n"; $run_present = 1; last; }
    }
    if($run_present ==1){
    open(my $rh,  $test_runsim);
    $run_pass=0;
         
    while (1)
    { 
      while (my $row = <$rh>)
      {
         chomp $row;
         if($row =~ m/CPU Time|Fatal: /)
         { print "$row\n"; $run_pass = 1; $row = <$rh>;}
      }
      if($run_pass == 1)
      { last; }
    }
    close $rh;
}

        ################################## Mailing Process for Basic and complex scenarios ####################################################
   
if($run_present == 1)
{
    open(my $ph,  $test_runsim)
    or die "Could not open file '$test_runsim' $!";

    print "Processing $test_runsim \n";
    $a = "FAILED";
    $b = "FAILED";

    while(my $row = <$ph>)
    {
      chomp $row;
      if($row =~ m/UVM_ERROR :    0/)
      { $a = "PASSED"; print "Found 0 UVM_ERROR in $test_runsim \n"; }

      if($row =~ m/UVM_FATAL :    0/  )
      { $b = "PASSED"; print "Found 0 UVM_FATAL in $test_runsim \n"; last; }

      if($row =~ m/NOTE: automatic random seed used:(\s*)(\d*)/)
      { $seed = $2; }
    }

    if($a eq "PASSED" && $b eq "PASSED")
      { $result = "PASSED"."\n"; }
    else 
      { $result = "FAILED"."\n"; }

    if($count == 0)
      { $data .= "<tr><td>Testcase Name</td><td>Seed value</td><td>Status</td></tr>"; $count++; }

    if($a eq "PASSED" && $b eq "PASSED")
      { $data .= "<tr><td>$testdir\_CONFIG_\ $mail_config</td><td>$seed</td><td>$result</td></tr>"; }
    else
      { $data .= "<tr><td>$testdir\_CONFIG_\ $mail_config</td><td>$seed</td><td><font size=\"3\" color=\"#FF0000\">$result</td></tr>"; }
    $run_present = 0;
}
elsif($run_present ==0)
{ $data .= "<tr><td>$testdir\_CONFIG_\ $mail_config</td><td>NA</td><td><font size=\"3\" color=\"#FF0000\">VCS ERROR</td></tr>"; }
}}}}}}

    $data .= "</table>";
    $data .= "<p> Result Dir - $scripts/results </p>";
    $data .= "<p> GIT Revision - $git_rev </p>";

my $sender = 'psse.-.sj.site@intel.com';
my $receiver = 'psse.-.sj.site@intel.com';
my $mail_host = 'smtp.intel.com';
my $msg_body ="Attached is a file";

         ################################### Post processing for email###########################################################

my $msg = MIME::Lite->new(
    From    => $sender,
    To      => $receiver,
    Subject => "Regression results for IOFS AC UVM simulations - Variant: $variant, Platform: $platform",
   Type    =>"multipart/mixed",
);


$msg->attach(Type         => 'text/html',
             Data         => $data 
             );

MIME::Lite->send('smtp',$mail_host , Timeout=>60);
$msg->send();
