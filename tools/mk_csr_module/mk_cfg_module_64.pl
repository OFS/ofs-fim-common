#!/usr/bin/perl
# Copyright 2021 Intel Corporation
# SPDX-License-Identifier: MIT

#
# file: ${script_dir}mk_cfg_module_64.pl
#----------------------------------------------------------------------------
#
#
# This script, mk_reg_def.pl generates these files:
#         Register Block RTL             ${rtl_file}
#         The Register Specification     ${spec_file}
#
# The input files used are:
#         register definition file       ${rtl_dir}${example_csrs.ini}
#         Register Block Template        ${rtl_dir}${template_file}
#         The perl script                ${script_dir}mk_cfg_module_64.pl
#
#=============================================================================
# Discription:
#=============================================================================
# DATA STRUCTURE ORGINATION
#
# Each array index in the data structure represents one bit in a cfg
# register (RTL register).  In this example, we will consider a 4K
# address space. Each address represents one byte (8 bits).  So with a
# 4K address space, there are (4096 * 8) or 32,768 indexes (32k) in each
# array variable.  There is a separate array variable for the
# information needed for each bit. i.e.@bit_name, @access, @reset_temp,
# @reset_value; Although this is not an efficient use of memory, entries
# for variables that occupy more than one bit are copied to all the bits
# (indexed) they occupy.  In other words, consider a register that has 4
# bits. The "@access" is common to all 4 bits. So the string for "type" is
# copied from offset 0 to offset 3 in the @access variable.  Likewise, the
# "group_name" variable is common to 256 * 8 (2K indexes), The
# "group_name" string is copied to all 2K "group_name" indexes.  This
# has the advantage of being able to get the "group_name" (or any entry)
# associated with a particular bit using only the bits index.
# (int((($current_register) - ((int($current_register / 256)) * 256)) /
# 8))
#
#
#
# good stuff to know.
# To shave off top bits... for a 12 bit number...
# The example below shaves off 4 top bits of $a_12_bit_number
# $new_number = (($a_12_bit_number) - ((int($a_12_bit_number / 256)) * 256));
# 4096 = 0 bits
# 2048 = 1 bits
# 1024 = 2 bits
# 0512 = 3 bits
# 0256 = 4 bits
# 0128 = 5 bits
# 0064 = 6 bits
# 0032 = 7 bits
# 0016 = 8 bits
# 0008 = 9 bits
# 0004 = 10 bits
# 0002 = 11 bits
# 0001 = 12 bits
#
# To shave off 3 bottom bits...
# $new_number = int($a_number / 8);
# 0 bits = 1
# 1 bits = 2
# 2 bits = 4
# 3 bits = 8
# 4 bits = 16
# 5 bits = 32
# 6 bits = 64
# 7 bits = 128
# 8 bits = 256


use strict;
use File::Basename;

my $project_name = "example_csrs.ini";

if ($ARGV[0] ne "") {
    if ($ARGV[0] =~ /^-h/) {
        print "Usage: mk_cfg_module_64.pl <ini_file_name>\n";
        print "Example: mk_cfg_module_64.pl <ini_file_name>\n";
        exit (0);
    } else {
        $project_name = $ARGV[0];
    }
} else {
    print "Usage: mk_cfg_module_64.pl <ini_file_name>\n";
    print "Example: mk_cfg_module_64.pl <ini_file_name>\n";
    exit (0);
}

if ($ARGV[0] eq "") {
    print "ERROR mk_cfg_module_64.pl requires the ini-file-name as the argumant\n";
    print "Usage: mk_cfg_module_64.pl <ini_file_name>\n";
    print "Example: mk_cfg_module_64.pl protocol_checker_csrs.ini\n";
    exit (0);
}

if ($project_name =~ /^(.+)_csrs\.ini$/) {
    $project_name = $1;
} else {
    print "ERROR: The ini file (the first and only argument) must end with \"_csrs.ini\"\n";
    print "EXAMPLE: mk_cfg_module_64.pl protocol_checker_csrs.ini\n";
     exit (0);
}

my $rtl_dir        = "./";
my $doc_dir        = "./";
my $xml_dir        = "./";
my $dv_dir         = "./";
my $script_dir = dirname(__FILE__);

my $reg_def_file   = "${rtl_dir}${project_name}_csrs.ini";
my $template_file  = "${rtl_dir}${project_name}_csr_template.sv";
my $rtl_file       = "${rtl_dir}${project_name}_csr.sv";
my $xml_file       = "${xml_dir}${project_name}_csr.xml";
my $spec_file      = "${doc_dir}${project_name}_csr_spec.html";

my $width          = 64; # changing this to 32 will not work. hard coded 64 bit stuff is everywhere.
my $addr_size;
my $bit_print;
my $bits_to_next_byte;
my $bp;
my $byte_en;
my $continue_loop;
my $current_bit;
my $current_group;
my $current_register;
my $crf0; # always has the current register first field bit.
my $current_register_fp;
my $file_line;
my $flag;
my $full_register_field_name;
my $hi_field_bit;
my $hi_reg_bit;
my $i;
my $j;
my $j_adjust;
my $k;
my $l;
my $lo_field_bit;
my $lo_hi_fp;
my $lo_hi_loop;
my $lo_hi_loop_end;
my $lo_reg_bit;
my $name_type_buf;
my $print_net;
my $print_net_1;
my $print_net_2;
my $reg_we_fp;
my $register_print;
my $rp;
my $search_string_found;
my $text_fp;
my $tmp_print;
my $uc_print;
my @default_reset_net;
my @number_of_bits;
my $have_current_register = 0;

my $register_name_a;
my $dont_spec_a;

my $reset_temp_fs;

my $upper;

#ADD_TEXT
my @add_text; # text till END

#NEXT_REG
my @register_name;
my @dont_spec;
my @reset_value_64;

#REGISTER_DESCRIPTION
my @register_description; # text till "

#NEXT_BIT
my $field_name_tmp;
my @field_name;
my @start_bit;
my @access;

my @reset_temp;
my @reset_value;

my @hi_bit;
my @lo_bit;

#LOAD_TERM
my @load_term_declare;
my @load_term_net;
my @load_data_net_declare;
my @load_data_net;

#SET_TERM
my @set_term_net_declare;
my @set_term_net_name;

#OUTPUT_PORT
my @output_port_name;
my @synchronize_to_clock;
my @pipeline_stages;

#SET_PULSE
my @set_pulse_port_name;

#FREEZE_CSR_NET_NAME
my @freeze_csr_net_name;# arg1

#DESCRIPTION_OF_FIELD
my @description_of_field;

# *************************************************************************************
my $lo_bit_tmp;
my $hi_bit_tmp;

my $addr_hi_bit;
my $addr_lo_bit;

my $in_addr_size = 0;
my $have_addr_size = 0;
my $working_on_fields = 0;
my $working_on_register = 0;
my $done_current = 0;
my $reg_def_line = 0;
my $leagal_agrument = 0;
my @write_rw_rtl;

open (DEF_FILE, "< $reg_def_file") || die "Can't open file $reg_def_file for reading\n";

while (<DEF_FILE>) {
    if (/^(.*?);.*$/) { # Remove comments from the file
        $_ = $1;
    }
    chomp;
    $reg_def_line = $reg_def_line + 1;
    #remove leading and trailing white space...
    while (/^(.*)\s$/) {$_ = $1;}
    while (/^\s(.*)$/) {$_ = $1;}

    if (/\[.*\]/) {
        #print "HELLO I HAVE SEEN A SQUARE paren. WORKING_ON_REGISTER: $working_on_register, WORKING_ON_FIELDS: $working_on_fields\n";
        if ($working_on_register |
            $working_on_fields) {
            $done_current = 1;
        }
    }

    if ($done_current) {
        if ($working_on_register) {
            #do working on register stuff
            $working_on_register = 0;
            $done_current        = 0;
            $i = $current_register * 64/8; # $i is pointing to bit zero in the field
            #printf ("current_register: %d 0x%X\n", $current_register, $current_register); # it's 0x418
            for($j = 0 ; $j <= 63; $j++) { # fill all 64 register names
                $k = $i + $j;
                if ($register_name[$k] ne "") {
                    printf ("ERROR Register 0x%03x bit %d is already defined to %s k:%d.File:%s, Line:%d\n", $current_register, $j, $register_name[$k], $k, $reg_def_file, $reg_def_line);
                    die;
                }
                $register_name[$k] = $register_name_a;
                $dont_spec[$k]     = $dont_spec_a;
            }
            #printf ("FINISHED FILLING IN THE 64 BITS FOR REGISTER 0x%X\n", $current_register);
        } elsif ($working_on_fields) {
            # **********************************************************************
            # *** We have all fields. Now copy then to all the bits in the field ***
            # **********************************************************************
            $working_on_fields = 0;
            $done_current      = 0;
            #printf ("filling in bit fields. Using current_register %d 0x%X\n", $current_register, $current_register);

            # set the defaults...
            if ($start_bit[$crf0] eq "")   {$start_bit[$crf0]=0;}
            if ($access[$crf0] eq "")      {$access[$crf0] = "RO";}
            if ($reset_value[$crf0] eq "") {$reset_value[$crf0] = 0;}
            if ($reset_temp[$crf0] eq "")  {$reset_temp[$crf0] = "WARM";}

            if ($access[$crf0] eq "RO")    {$reset_temp[$crf0] = "WARM";} # - reset_temp - NA.
            if ($access[$crf0] eq "ROS")   {$reset_temp[$crf0] = "COLD";}
            if ($access[$crf0] eq "RW")    {$reset_temp[$crf0] = "WARM";}
            if ($access[$crf0] eq "RWS")   {$reset_temp[$crf0] = "COLD";}
            if ($access[$crf0] eq "RW1C")  {$reset_temp[$crf0] = "WARM";}
            if ($access[$crf0] eq "RW1CS") {$reset_temp[$crf0] = "COLD";}
            if ($access[$crf0] eq "RW1S")  {$reset_temp[$crf0] = "WARM";}
            if ($access[$crf0] eq "RW1SS") {$reset_temp[$crf0] = "COLD";}
            if ($access[$crf0] eq "Rsvd")  {$reset_temp[$crf0] = "WARM";} # NOT SUPPORTING
            if ($access[$crf0] eq "RsvdP") {$reset_temp[$crf0] = "WARM";} # NOT SUPPORTING
            if ($access[$crf0] eq "RsvdZ") {$reset_temp[$crf0] = "WARM";} # - reset_temp - NA. This is the default for fields that are not declaired.

            if ($pipeline_stages[$crf0] eq "")                        {$pipeline_stages[$crf0] = 0;}

            for($j = $lo_bit[$crf0] ; $j <= $hi_bit[$crf0]; $j++) {
                $i = ($current_register * 64/8) + $j;
                if ($field_name[$i] ne "") {
                    printf ("ERROR Bit %d in Register 0x%03x already defined to %s.\n", $j, $current_register, $field_name[$i]);
                    die;
                }
                $field_name[$i]         = $field_name_tmp;
                $number_of_bits[$i]     = ($hi_bit[$crf0] - $lo_bit[$crf0] + 1);
                #print "number_of_bits[$i] $number_of_bits[$i]\n";
                $register_name[$i]      = $register_name[($current_register * 8)];
                $dont_spec[$i]          = $dont_spec[($current_register * 8)];

                $hi_bit[$i]             = $hi_bit[$crf0];
                $lo_bit[$i]             = $lo_bit[$crf0];
                $start_bit[$i]          = $start_bit[$crf0];
                $access[$i]             = $access[$crf0];
                $reset_temp[$i]         = $reset_temp[$crf0];
                $reset_value[$i]        = $reset_value[$crf0];

                $load_term_net[$i]             = $load_term_net[$crf0];
                $load_term_declare[$i]         = $load_term_declare[$crf0];
                $load_data_net[$i]             = $load_data_net[$crf0];
                $load_data_net_declare[$i]     = $load_data_net_declare[$crf0];

                $set_term_net_name[$i]         = $set_term_net_name[$crf0];
                $set_term_net_declare[$i]      = $set_term_net_declare[$crf0];

                $output_port_name[$i]          = $output_port_name[$crf0];
                $synchronize_to_clock[$i]      = $synchronize_to_clock[$crf0];
                $pipeline_stages[$i]           = $pipeline_stages[$crf0];

                $set_pulse_port_name[$i]       = $set_pulse_port_name[$crf0];
                $freeze_csr_net_name[$i]       = $freeze_csr_net_name[$crf0];
                $description_of_field[$i]      = $description_of_field[$crf0];

            }
        }
    }
    if (/\[ADDR_SIZE\]/i) {
        $in_addr_size = 1;
    }

    if ($in_addr_size) {
        if (/space\s*\=\s*([0-9]+):([0-9]+)/){
            $addr_hi_bit = $1;
            $addr_lo_bit = $2;
            if ($addr_lo_bit > $addr_hi_bit) {
                printf ("Syntax error addr_size: The high bit must be greater than the low bit.. line %d of %s. Register:%0x\n", $reg_def_line, $reg_def_file, $current_register);
                die;
            }
            #printf ("1) Here addr_size is: %d 0x%X\n", $addr_size, $addr_size);
            $in_addr_size = 0;
            $have_addr_size = 1;
        }
    }

    #printf ("%f\n", (2**$addr_hi_bit));

    if  ($have_addr_size) {
        if ($working_on_fields) {
            #print "working_on_fields:$working_on_fields\n";
            $leagal_agrument = 0;

            # *********************************************************
            # *** Get range (hi and lo bit numbers in the register) ***
            # *********************************************************
            if (/\s*range/) {
                if (/range\s*\=\s*([0-9]+):([0-9]+)/i){
                    $hi_bit_tmp = $1;
                    $lo_bit_tmp = $2;
                    if ($lo_bit_tmp > $hi_bit_tmp) {
                        printf ("Syntax error range: the high bit must be greater than the low bit.. line %d of %s. Register:%0x\n", $reg_def_line, $reg_def_file, $current_register);
                        die;
                    }
                    $leagal_agrument = 1;
                } elsif (/range\s*\=\s*([0-9]+)/i){
                    $hi_bit_tmp = $1;
                    $lo_bit_tmp = $1;
                    $leagal_agrument = 1;
                } else {
                    printf ("Syntax error range, start_bit. line %d of %s. Register:%0x\n", $reg_def_line, $reg_def_file, $current_register);
                    die;
                }
                $crf0 = $current_register * 64/8 + $lo_bit_tmp; # crf0 (current register field lo bit)
            }
            if ($crf0 eq "") {
                printf ("Range must be the first field after defining the field name. line %d of %s. Register:%0x\n", $reg_def_line, $reg_def_file, $current_register);
                die;
            }
            $hi_bit[$crf0] = $hi_bit_tmp;
            $lo_bit[$crf0] = $lo_bit_tmp;
            # *************************
            # *** We have the range ***
            # *************************


            if (/\s*start_bit/) {
                if (/start_bit\s*\=\s*([0-9]+)$/) {
                    $start_bit[$crf0] = $1;
                    $leagal_agrument = 1;
                } else {
                    printf ("Syntax error start_bit. line %d of %s. Register:%0x\n", $reg_def_line, $reg_def_file, $current_register);
                    die;
                }
            }
            if (/\s*access/) {
                if (/access\s*\=\s*(\S+)$/) {
                    $access[$crf0] = $1;
                    if (
                        ($access[$crf0] eq "RO") |
                        ($access[$crf0] eq "ROS") |
                        ($access[$crf0] eq "RW") |
                        ($access[$crf0] eq "RSC") |
                        ($access[$crf0] eq "RS") |
                        ($access[$crf0] eq "RC") |
                        ($access[$crf0] eq "RW1CS")
                        ) {
                        $leagal_agrument = 1;
                    } else {
                        printf ("Syntax error access. unknown access %s. line %d of %s. Register:%0x\n", $access[$crf0], $reg_def_line, $reg_def_file, $current_register);
                        die;
                    }
                } else {
                    printf ("Syntax error access. line %d of %s. Register:%0x\n", $reg_def_line, $reg_def_file, $current_register);
                    die;
                }
            }
            if (/\s*reset_temp\s*\=/) {
                if (/reset_temp\s*\=\s*(\S+)$/) {
                    $reset_temp[$crf0] = $1;
                    if (
                        ($reset_temp[$crf0] eq "COLD")   |
                        ($reset_temp[$crf0] eq "WARM")   |
                        ($reset_temp[$crf0] eq "NONE")   |
                        ($reset_temp[$crf0] eq "STICKY") |
                        ($reset_temp[$crf0] eq "NORMAL")
                        ) {
                        $leagal_agrument = 1;
                    } else {
                        printf ("Syntax error reset. line %d of %s. Register:%0x\n", $reg_def_line, $reg_def_file, $current_register);
                        die;
                    }
                } else {
                    printf ("Syntax error reset. line %d of %s. Register:%0x\n", $reg_def_line, $reg_def_file, $current_register);
                    die;
                }
            }
            if (/\s*reset_value/) {
                if (/reset_value\s*\=\s*0x([0-9a-f]+)\s*$/i) {
                    $reset_value[$crf0] = hex($1);
                    $leagal_agrument = 1;
                } elsif (/reset_value\s*\=\s*([0-9]+)\s*$/i) {
                    $reset_value[$crf0] = $1;
                    $leagal_agrument = 1;
                } else {
                    printf ("Syntax error reset_value. line %d of %s. Register:%0x\n", $reg_def_line, $reg_def_file, $current_register);
                    die;
                }
            }
            if (/load_term_net\s*\=\s*(\S+)$/) {
                $load_term_net[$crf0] = $1;
                if ($load_term_net[$crf0] =~ /^[a-z0-9_\.\[\]]+$/i) {
                    $leagal_agrument = 1;
                } else {
                    printf ("Syntax error load_term_net. Illegal charactor. line %d of %s. Register:%0x\n", $reg_def_line, $reg_def_file, $current_register);
                    die;
                }
                $leagal_agrument = 1;
            }
            if (/load_term_declare\s*\=\s*(\S+)$/) {
                $load_term_declare[$crf0] = $1;
                if (
                    ($load_term_declare[$crf0] eq "NO") |
                    ($load_term_declare[$crf0] eq "LOGIC") |
                    ($load_term_declare[$crf0] eq "PORT")
                    ) {
                    $leagal_agrument = 1;
                } else {
                    printf ("Syntax error load_term_declare. line %d of %s. Register:%0x\n", $reg_def_line, $reg_def_file, $current_register);
                    die;
                }
            }
            if (/load_data_net\s*\=\s*(\S+)$/) {
                $load_data_net[$crf0] = $1;
                $leagal_agrument = 1;
            }
            if (/load_data_net_declare\s*\=\s*(\S+)$/) {
                $load_data_net_declare[$crf0] = $1;
                if (
                    ($load_data_net_declare[$crf0] eq "NO") |
                    ($load_data_net_declare[$crf0] eq "LOGIC") |
                    ($load_data_net_declare[$crf0] eq "PORT")
                    ) {
                    $leagal_agrument = 1;
                }
            }
            if (/set_term_net_name\s*\=\s*(\S+)$/) {
                $set_term_net_name[$crf0] = $1;
                $leagal_agrument = 1;
            }
            if (/set_term_net_declare\s*\=\s*(\S+)$/) {
                $set_term_net_declare[$crf0] = $1;
                if (
                    ($set_term_net_declare[$crf0] eq "NO") |
                    ($set_term_net_declare[$crf0] eq "LOGIC") |
                    ($set_term_net_declare[$crf0] eq "PORT")
                    ) {
                    $leagal_agrument = 1;
                }
            }
            if (/output_port_name\s*\=\s*(\S+)$/) {
                $output_port_name[$crf0] = $1;
                $leagal_agrument = 1;
            }
            if (/synchronize_to_clock\s*\=\s*(\S+)$/) {
                $synchronize_to_clock[$crf0] = $1;
                $leagal_agrument = 1;
            }
            if (/pipeline_stages\s*\=\s*([0-9]+)$/) {
                $pipeline_stages[$crf0] = $1;
                $leagal_agrument = 1;
            }
            if (/set_pulse_port_name\s*\=\s*(\S+)$/) {
                $set_pulse_port_name[$crf0] = $1;
                $leagal_agrument = 1;
            }
            if (/freeze_csr_net_name\s*\=\s*(\S+)$/) {
                $freeze_csr_net_name[$crf0] = $1;
                $leagal_agrument = 1;
            }
            if (/description_of_field\s*\=.*\"(.*)\"$/) {
                $description_of_field[$crf0] = $1;
                $leagal_agrument = 1;
            }
            if (/^\s*$/) {
                #print "Blank line\n";
            } else {
                if (!($leagal_agrument)) {
                    printf ("Syntax error unknown argument found. line %d of %s. Register:%0x\n", $reg_def_line, $reg_def_file, $current_register);
                    die;
                }
            }
        }

        if (/\[.+\.(.+)\]/) { # Detect that you are working on fields because it has a dot "."
            $field_name_tmp = $1;
            $working_on_fields = 1;
            if (!($field_name_tmp =~ /^[0-9a-z_]+$/)) {
                printf ("Field names may only have lower case a-z, numbers 0-9 or the \"_\" chars. Signal name found is: \"%s\"\n", $field_name_tmp);
                die;
            }
        }

        if ($working_on_register) {
            $leagal_agrument = 0;
            if (/\s*offset/) {
                if (/\s*offset\s*\=\s*0x([0-9a-f]+)\s*$/i) {
                    $current_register = hex($1);
                    $crf0 = "";
                    $have_current_register = 1;
                    $leagal_agrument = 1;
                } elsif (/\s*offset\s*\=\s*([0-9]+)\s*$/i) {
                    $current_register = $1;
                    $have_current_register = 1;
                    $leagal_agrument = 1;
                } else {
                    printf ("Syntax error offset. line %d of %s.\n", $reg_def_line, $reg_def_file);
                    die;
                }
                if (($current_register / 8) != int($current_register / 8)) {
                    printf ("Syntax error offset. offset must modulus 8 0x%X. line %d of %s.\n", $current_register, $reg_def_line, $reg_def_file);
                    die;
                }
            }
            if (/\s*dont_spec/) {
                if (/dont_spec\s*\=\s*([0-9]+)$/) { # Not supported yet.
                    $dont_spec_a                 = $1;
                    $leagal_agrument = 1;
                }
            }
            if (/^\s*$/) {
                #print "Blank line\n";
            } else {
                if (!($leagal_agrument)) {
                    printf ("Syntax error unknown argument Reg. line %d of %s. Register:%0x\n", $reg_def_line, $reg_def_file, $current_register);
                    die;
                }
            }
        }
        if (/\[(\S+)\]/) {
            if ((!($working_on_register)) & (!($working_on_fields))) {
                $register_name_a = $1;
                if (!($register_name_a =~ /\./)) {
                    $working_on_register = 1;
                    #print "I FOUND ANOTHER REGISTER. Name:$register_name_a\n";
                }
            }
        }
    } # have_addr_size
}
close (DEF_FILE);

$current_bit = 0;
# ****************************
# *** Set all the defaults ***
# ****************************
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i++) {
    #$current_register       = $i / 8;
    $current_register       = (int ($i / 64) * 8);
    if ($register_name[$i] ne "") {
        #load_term_net
        if ($load_term_net[$i] eq "NO") {
            $load_term_net[$i] = "";
        }
        if ($load_term_net[$i] eq "YES") {
            $load_term_net[$i] = $field_name[$i];
        }
        if ($load_term_net[$i] eq "TRUE") {
            $load_term_net[$i] = "1'b1";
            $load_term_declare[$i] = "";
        } elsif ($load_term_net[$i] ne "") {
            if ($load_term_declare[$i] eq "PORT") {
                $load_term_net[$i] = "i_ld_$load_term_net[$i]";
            } else {
                $load_term_net[$i] = "ld_$load_term_net[$i]";
            }
        }

        if ($load_term_declare[$i] eq "NO") {
            $load_term_declare[$i] = "";
        }

        #load_data_net
        if ($load_data_net[$i] eq "NO") {
            $load_data_net[$i] = "";
        }
        if ($load_data_net[$i] eq "YES") {
            $load_data_net[$i] = $field_name[$i];
        }
        if ($load_data_net[$i] ne "") {
            if ($load_data_net_declare[$i] eq "PORT") {
                $load_data_net[$i] = "i_$load_data_net[$i]_load_data";
            } else {
                $load_data_net[$i] = "$load_data_net[$i]_load_data";
            }
        }
        
        if ($load_data_net_declare[$i] eq "NO") {
            $load_data_net_declare[$i] = "";
        }

        #set_term_net_name
        if ($set_term_net_name[$i] eq "NO") {
            $set_term_net_name[$i] = "";
        }
        if ($set_term_net_name[$i] eq "YES") {
            $set_term_net_name[$i] = $field_name[$i];
        }
        if ($set_term_net_name[$i] ne "") {
            if ($set_term_net_declare[$i] eq "PORT") {
                $set_term_net_name[$i] = "i_set_$set_term_net_name[$i]";
            } else {
                $set_term_net_name[$i] = "set_$set_term_net_name[$i]";
            }
        }
        if (($set_term_net_name[$i] eq "i_set_TRUE") | ($set_term_net_name[$i] eq "set_TRUE")) {
            $set_term_net_name[$i]   = "1'b1";
            $set_term_net_declare[$i] = "NO";
        }
        if ($set_term_net_declare[$i] eq "NO") {
            $set_term_net_declare[$i] = "";
        }
        if ($output_port_name[$i] eq "YES") {
            $output_port_name[$i] = "o_$field_name[$i]_reg";
        }
        if ($output_port_name[$i] eq "NO") {
            $output_port_name[$i] = "";
        }

        if ($set_pulse_port_name[$i] eq "YES") {
            $set_pulse_port_name[$i] = $field_name[$i];
        }
        if ($set_pulse_port_name[$i] ne "") {
           $set_pulse_port_name[$i] = "o_$set_pulse_port_name[$i]_pulse"; 
        }

        if ($reset_temp[$i] eq "WARM") {
            $reset_temp[$i] = "rst_n_csr";
        } elsif ($reset_temp[$i] eq "NONE") {
            $reset_temp[$i] = "1'b1";
        } else {
            $reset_temp[$i] = "pwr_good_csr_clk_n";
        }
        
        $write_rw_rtl[$i] = 1;
        if (($load_term_net[$i] eq "") & ($load_term_declare[$i] eq "") & ($load_data_net_declare[$i] eq "") & ($set_term_net_name[$i] eq "") & ($set_term_net_declare[$i] eq "") & ($output_port_name[$i] eq "") & ($synchronize_to_clock[$i] eq "") & ($pipeline_stages[$i] eq "") & ($freeze_csr_net_name[$i] eq "")) {
            if (($set_pulse_port_name[$j] ne "") & (($access[$j] eq "RO") | ($access[$j] eq "RW"))) {$access[$j] = "RW"; $write_rw_rtl[$i] = 0}
        }
    }


    if ($current_bit == 63) {
        $current_bit = 0;
    } else {
        $current_bit++;
    }
}



# *******************************************
# *** Calculate the registers reset value ***
# *******************************************
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    $current_register       = (int ($i / 64) * 8);
    if ($register_name[$i] ne "") {
        my $bin_no;
        my $s4b = "";
        for ($j = ($i + 63); $j >= $i; $j--) { # run through the bits in this register (NOTE!!! j is modified)
            if ($field_name[$j] ne "") { # If this bit is not reserved...
                $bin_no = sprintf ("%b", $reset_value[$j]);
                my $zadd = $number_of_bits[$j] - length($bin_no);
                for (my $i = 0;$i < $zadd;$i++) {
                    $bin_no = "0".$bin_no;
                }

                $s4b =$s4b.$bin_no;
                
                # adjust $j for next bit (after this vector)
                $j = $j - ($number_of_bits[$j] - 1);
            } else { # it is a reserved bit -OR- the ENTIRE register is not defined
                if ($register_name[$j] ne "") { # if the register is defined...
                    $hi_bit[$j] = $current_bit;
                    $continue_loop = 1;
                    for ($k = $j; $continue_loop; $k--) {
                        $current_register       = (int ($k / 64) * 8);
                        $current_bit            = $k - ($current_register * 64/8);
                        if ($field_name[$k] ne "") {
                            $k++;
                            $continue_loop = 0;
                        }
                        if ($current_bit == 0) {
                            $continue_loop = 0;
                        }
                    }
                    $k = $k + 1; #this puts $k at the last reserved bit
                    $current_register       = (int ($k / 64) * 8);
                    $current_bit            = $k - ($current_register * 64/8);
                    for ($l = $k; $l <= $j; $l++) { # fill all the bits with the width
                        $number_of_bits[$l] = $j - ($k - 1);
                    }
                    $lo_bit[$j] = $current_bit;
                    
                    $bin_no = sprintf ("%b", 0);
                    my $zadd = $number_of_bits[$j] - length($bin_no);
                    for (my $i = 0;$i < $zadd;$i++) {
                        $bin_no = "0".$bin_no;
                    }
                    
                    $s4b =$s4b.$bin_no;

                    $j = $j - ($number_of_bits[$j] - 1);
                } else { # the ENTIRE register is not defined. Do (almost) nothing.
                    $j = $j - 63;
                }
            }
        }
        for ($j=$i;$j<$i+64;$j++) { # Fill in every bit in the register.
            $reset_value_64[$j] = sprintf ("%d", oct("0b".$s4b));
        }
    }
}


if (0) {
    printf ("current  register        field      hi  lo  num dnt sta access     reset     reset   load            load             load             load           set              set              output      synchronize pipeline set         freeze\n");
    printf ("register   name          name       bit bit of  spc bit            temp      value   term            term             data             data           term net         term net          port       clock       stages   pulse port  csr\n");
    printf ("                                            bts                                      net             declare          net              declare        name             declare                                           name \n");
    for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 1) {
        if ($field_name[$i] ne "") {
            $current_register = (int ($i / 64) * 8);
            #000,   afu_intf_dfh,     feature_id, 11,  0, 12,  0,  0,  RO,      rst_n_csr,0010,               ,               ,               ,               ,               ,               ,               ,               ,00,               ,               
            #000,   afu_intf_dfh,     feature_id, 11,  0, 12,  0,  0,  RO,      rst_n_csr,0010,               ,               ,               ,               ,               ,               ,               ,               ,00,               ,               
            printf ("%d %03X,%15s,%15s,%3d,%3d,%3d,%3d,%3d,%4s,%15s,%4X,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s,%15s\n",
                    $i,
                    $current_register,             #01
                    $register_name[$i],            #02
                    $field_name[$i],               #03
                    $hi_bit[$i],                   #04
                    $lo_bit[$i],                   #05
                    $number_of_bits[$i],           #06
                    $dont_spec[$i],                #07
                    $start_bit[$i],                #08
                    $access[$i],                   #09
                    $reset_temp[$i],               #10
                    $reset_value[$i],              #11
                    $load_term_net[$i],            #12
                    $load_term_declare[$i],        #13
                    $load_data_net[$i],            #14
                    $load_data_net_declare[$i],    #15
                    $set_term_net_name[$i],        #16
                    $set_term_net_declare[$i],     #17
                    $output_port_name[$i],         #18
                    $synchronize_to_clock[$i],     #29
                    $pipeline_stages[$i],          #20
                    $set_pulse_port_name[$i],      #21
                    $freeze_csr_net_name[$i]);     #22
            
            #$description_of_field[$i]);           #23
        }
    }
}


# ****************************************************
# The entire data base with all register information
# has been read into the arrays
# ****************************************************
#
open (TEMPLATE_FILE, "< $template_file")   || die "Can't open input file for input: $template_file\n";
open (CSR_TOP,       "> $rtl_file")        || die "Can't open output file for output: $rtl_file\n";
#*****************************************************
#copy template until port inputs string is found.
#*****************************************************
$search_string_found = 0;
while (!$search_string_found) {
    $file_line = <TEMPLATE_FILE>;
    if ($file_line =~ /BEGIN TEMPLATE/) {
        $search_string_found = 1;
    } else {
        printf CSR_TOP ("%s", $file_line);
    }
    if (eof (TEMPLATE_FILE)) {
        die "Never found the string \"BEGIN TEMPLATE\" in $template_file\n";
    }
}
#*****************************************************
# print two more lines
#*****************************************************
printf CSR_TOP ("%s", $file_line);
printf CSR_TOP ("//\n");
printf CSR_TOP ("// *******************************************************\n");
printf CSR_TOP ("// *** WARNING!! ** WARNING!! ** WARNING!! ** WARNING!!***\n");
printf CSR_TOP ("// ***             DO NOT EDIT THIS FILE!!             ***\n");
printf CSR_TOP ("// *******************************************************\n");
printf CSR_TOP ("// This file is automatically generated from the files:\n");
printf CSR_TOP ("// ${reg_def_file} and ${template_file} using the perl\n");
printf CSR_TOP ("// program mk_reg_def.pl. Modify one of these files if you wish to make a change to\n");
printf CSR_TOP ("// this file.\n");
printf CSR_TOP ("//\n");
printf CSR_TOP ("// The mk_cfg_module_64.pl script generates these files:\n");
printf CSR_TOP ("//         Register Block RTL (this file) ${rtl_file}\n");
printf CSR_TOP ("//         The Register Specification     ${spec_file}\n");
printf CSR_TOP ("//\n");
printf CSR_TOP ("// The input files used are:\n");
printf CSR_TOP ("//         register definition file       ${reg_def_file}\n");
printf CSR_TOP ("//         Register Block Template        ${template_file}\n");
printf CSR_TOP ("//         The perl script                ${script_dir}\\mk_cfg_module_64.pl\n");
printf CSR_TOP ("//\n");

#*****************************************************
#copy template until "this_is_filled_in_by_mk_cfg_module" string is found.
#*****************************************************
$search_string_found = 0;
while (!$search_string_found) {
    $file_line = <TEMPLATE_FILE>;
    if ($file_line =~ /^(.+)this_is_filled_in_by_mk_cfg_module(.*)$/) {
        $file_line = $1.$addr_hi_bit.$2;
        $search_string_found = 1;
    }
    if (eof (TEMPLATE_FILE)) {
        die "Never found the string: \"this_is_filled_in_by_mk_cfg_module\" in $template_file\n";
    }
    printf CSR_TOP ("%s", $file_line);
}

#*****************************************************
#copy template until port inputs string is found.
#*****************************************************
$search_string_found = 0;
while (!$search_string_found) {
    $file_line = <TEMPLATE_FILE>;
    if ($file_line =~ /Start Auto generated input port list/) {
        $search_string_found = 1;
    } else {
        printf CSR_TOP ("%s", $file_line);
    }
    if (eof (TEMPLATE_FILE)) {
        die "Never found the string: \"Start Auto generated input port list\" in $template_file\n";
    }
}
#*****************************************************
# print two more lines
#*****************************************************
printf CSR_TOP ("%s", $file_line);
$file_line = <TEMPLATE_FILE>;
printf CSR_TOP ("%s", $file_line);

#*****************************************************
#print known input ports
#*****************************************************
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    for ($j = ($i + 63); $j >= $i; $j--) {
        $current_register       = (int ($j / 64) * 8);
        $current_group          = (int ($current_register / 256));
        if ($register_name[$j] ne "") {
            if ($load_term_declare[$j] eq "PORT") {
                printf CSR_TOP ("   ,input logic        %-35s // load term for register  0x%03x %-25s bit  %02d    (%s)\n", $load_term_net[$j], $current_register, $register_name[$j], $lo_bit[$j], $field_name[$j]);
            }
            if ($load_data_net_declare[$j] eq "PORT") {
                if ($number_of_bits[$j] == 1) {
                    printf CSR_TOP ("   ,input logic        %-35s // load data for register  0x%03x %-25s bit  %02d    (%s)\n", $load_data_net[$j], $current_register, $register_name[$j], $lo_bit[$j], $field_name[$j]);
                } else {
                    printf CSR_TOP ("   ,input logic[%02d:%02d] %-35s // load data for register  0x%03x %-25s bits %02d:%02d (%s)\n", ($start_bit[$j] + $number_of_bits[$j] - 1), $start_bit[$j], $load_data_net[$j], $current_register, $register_name[$j], $hi_bit[$j], $lo_bit[$j], $field_name[$j]);
                }
            }
            if ($set_term_net_declare[$j] eq "PORT") {
                printf CSR_TOP ("   ,input logic        %-35s // set term for register   0x%03x %-25s bit  %02d    (%s)\n", $set_term_net_name[$j], $current_register, $register_name[$j], $lo_bit[$j], $field_name[$j]);
            }
        }
        if ($number_of_bits[$j] ne "") {
            $j = $j - ($number_of_bits[$j] - 1);
        }
    }
}

#*****************************************************
#copy template until port outputs string is found.
#*****************************************************
$search_string_found = 0;
while (!$search_string_found) {
    $file_line = <TEMPLATE_FILE>;
    if ($file_line =~ /Start Auto generated output port list/) {
        $search_string_found = 1;
    } else {
        printf CSR_TOP ("%s", $file_line);
    }
    if (eof (TEMPLATE_FILE)) {
        die "Never found the string: \"Start Auto generated output port list\" in $template_file\n";
    }
}

#*****************************************************
# print two more lines
#*****************************************************
printf CSR_TOP ("%s", $file_line);
$file_line = <TEMPLATE_FILE>;
printf CSR_TOP ("%s", $file_line);

#*****************************************************
# print known output ports
#*****************************************************
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    for ($j = ($i + 63); $j >= $i; $j--) {
        $current_register       = (int ($j / 64) * 8);
        $current_group          = (int ($current_register / 256));
        if ($register_name[$j] ne "") {
            if (($output_port_name[$j] ne "NO") && ($output_port_name[$j] ne "")) {
                if ($number_of_bits[$j] == 1) {
                    printf CSR_TOP ("   ,output logic            %-35s // output of register      0x%03x %-25s bit  %02d    (%s)\n", $output_port_name[$j], $current_register, $register_name[$j], $lo_bit[$j], $field_name[$j]);
                } else {
                    printf CSR_TOP ("   ,output logic[%02d:%02d] %-35s // output of register      0x%03x %-25s bits %02d:%02d (%s)\n", ($start_bit[$j] + $number_of_bits[$j] - 1), $start_bit[$j], $output_port_name[$j], $current_register, $register_name[$j], $hi_bit[$j], $lo_bit[$j], $field_name[$j]);
                }
            }
            if ($set_pulse_port_name[$j] ne "") {
                printf CSR_TOP ("   ,output logic        %-35s // Set pulse of register   0x%03x %-25s bit  %02d    (%s)\n", $set_pulse_port_name[$j], $current_register, $register_name[$j], $lo_bit[$j], $field_name[$j]);
            }
        }
        if ($number_of_bits[$j] ne "") {
            $j = $j - ($number_of_bits[$j] - 1);
        }
    }
}

$search_string_found = 0;
while (!$search_string_found) {
    $file_line = <TEMPLATE_FILE>;
    if ($file_line =~ /Start Auto generated reg and wire decls/) {
        $search_string_found = 1;
    } else {
        printf CSR_TOP ("%s", $file_line);
    }
    if (eof (TEMPLATE_FILE)) {
        die "Never found the string: \"Start Auto generated reg and wire decls\" in $template_file\n";
    }
}
#*****************************************************
# print two more lines
#*****************************************************
printf CSR_TOP ("%s", $file_line);
$file_line = <TEMPLATE_FILE>;
printf CSR_TOP ("%s", $file_line);

for($i = 0; $i < (2**($addr_hi_bit+1)); $i = $i + 256) {
    $upper = $i/256;
    printf CSR_TOP ("   logic   decode_%02d_8_%02d;\n", $addr_hi_bit, $upper);
}        

#*****************************************************
#print known wires and regs
#*****************************************************
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    $current_register       = (int ($i / 64) * 8);
    $current_group          = (int ($current_register / 256));
    if ($register_name[$i] ne "") {
        if ($register_name[$i] ne "") {
            printf CSR_TOP ("\n");
            printf CSR_TOP ("   // ******************************************************\n");
            printf CSR_TOP ("   // Register 0x%03x %s\n", $current_register, $register_name[$i]);
            printf CSR_TOP ("   // ******************************************************\n");
            printf CSR_TOP ("   logic [63:00] %-40s // Register 0x%03x\n", "$register_name[$i]\_wire;", $current_register);
        }
        for ($j = ($i + 63); $j >= $i; $j--) {
            $current_register       = (int ($j / 64) * 8);
            $current_group          = (int ($current_register / 256));
            if ($field_name[$j] ne "") {
                if ( (($access[$j] eq "RO") | ($access[$j] eq "ROS")) & ($set_term_net_name[$j] eq "") & ($load_term_net[$j] eq "") & ($load_data_net[$j] eq "")) {
                    #printf ("Bits %02d:%02d (%s) in register offset 0x%03x, (%s) is read-only of static values\n", $hi_bit[$j], $lo_bit[$j], $field_name[$j], $current_register, $register_name[$j]);
                    if ($number_of_bits[$j] == 1) {
                        printf CSR_TOP ("   logic         %-40s // bit(s) %02d:%02d\n", "$field_name[$j]\_reg;", $hi_bit[$j], $lo_bit[$j]);
                    } else {
                        printf CSR_TOP ("   logic [%02d:%02d] %-40s // bit(s) %02d:%02d\n", ($start_bit[$j] + $number_of_bits[$j] - 1), $start_bit[$j], "$field_name[$j]\_reg;", $hi_bit[$j], $lo_bit[$j]);
                    }
                } else {
                    if ($number_of_bits[$j] == 1) {
                        printf CSR_TOP ("   logic         %-40s // bit(s) %02d:%02d\n", "$field_name[$j]\_reg;", $hi_bit[$j], $lo_bit[$j]);
                    } else {
                        printf CSR_TOP ("   logic [%02d:%02d] %-40s // bit(s) %02d:%02d\n", ($start_bit[$j] + $number_of_bits[$j] - 1), $start_bit[$j], "$field_name[$j]\_reg;", $hi_bit[$j], $lo_bit[$j]);
                    }
                }
            }
            if ($number_of_bits[$j] ne "") {
                $j = $j - ($number_of_bits[$j] - 1);
            }
        }
        printf CSR_TOP ("\n");
    }
}
printf CSR_TOP ("   logic         rd_or_wr_r2;\n");

print CSR_TOP "\n";
print CSR_TOP "   // *****************************************************\n";
print CSR_TOP "   // Logic declairs for the 8 bit \"register\" decode nets.\n";
print CSR_TOP "   // *****************************************************\n";
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    if ($register_name[$i] ne "") {
        printf CSR_TOP ("   logic         %s_en_r3;\n", $register_name[$i]);
    }
}

printf CSR_TOP ("   logic [63:00] csr_decode_mux_r4;\n");

print CSR_TOP "   // ******************************************************\n";
print CSR_TOP "   // *declair logics that are terms but not ports.\n";
print CSR_TOP "   // ******************************************************\n";
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    for ($j = ($i + 63); $j >= $i; $j--) {
        $current_register = (int ($j / 64) * 8);
        if ($register_name[$j] ne "") {
            if (($set_term_net_declare[$j] eq "LOGIC") && ($set_term_net_name[$j] ne "") && ($set_term_net_name[$j]=~ /^[A-Za-z0-9_]+\Z/)) {
                printf CSR_TOP ("  logic          %s; // set term for register 0x%03x %s bit(s) %02d:%02d (%s)\n", $set_term_net_name[$j], $current_register, $register_name[$j], $hi_bit[$j], $lo_bit[$j], $field_name[$j]);
            }
            if (($load_term_declare[$j] eq "LOGIC") && ($load_term_net[$j] ne "") && ($load_term_net[$j]=~ /^[A-Za-z0-9_]+\Z/)) {
                printf CSR_TOP ("  logic          %s; // load term for register 0x%03x %s bit(s) %02d:%02d (%s)\n", $load_term_net[$j], $current_register, $register_name[$j], $hi_bit[$j], $lo_bit[$j], $field_name[$j]);
            }
            if (($load_data_net_declare[$j] eq "LOGIC") && ($load_data_net[$j] ne "") && ($load_data_net[$j]=~ /^[A-Za-z0-9_]+\Z/)) {
                if ($number_of_bits[$j] == 1) {
                    printf CSR_TOP ("  logic          %s; // load data for register 0x%03x %s bit(s) %02d:%02d (%s)\n", $load_data_net[$j], $current_register, $register_name[$j], $hi_bit[$j], $lo_bit[$j], $field_name[$j]);
                } else {
                    printf CSR_TOP ("  logic  [%02d:%02d] %s; // load data for register 0x%03x %s bit(s) %02d:%02d (%s)\n", ($start_bit[$j] + $number_of_bits[$j] - 1), $start_bit[$j], $load_data_net[$j], $current_register, $register_name[$j], $hi_bit[$j], $lo_bit[$j], $field_name[$j]);
                }
            }

            if ($number_of_bits[$j] ne "") {
                $j = $j - ($number_of_bits[$j] - 1);
            }
        }
    }
}

print CSR_TOP "   // ******************************************************\n";
print CSR_TOP "   // *default reset value wires..\n";
print CSR_TOP "   // ******************************************************\n";
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    for ($j = ($i + 63); $j >= $i; $j--) {
        $current_register       = (int ($j / 64) * 8);
        $current_group          = (int ($current_register / 256));
        if ($field_name[$j] ne "") {
            if ($number_of_bits[$j] == 1) {
                printf CSR_TOP ("  logic           %s_default = 1'b%x;\n", $field_name[$j], $reset_value[$j]);
            } else {
                printf CSR_TOP ("  logic   [%02d:%02d] %s_default = %d'h%X;\n", ($number_of_bits[$j] - 1 + $start_bit[$j]), $start_bit[$j], $field_name[$j], $number_of_bits[$j], $reset_value[$j]);
            }
        }
        if ($number_of_bits[$j] ne "") {
            $j = $j - ($number_of_bits[$j] - 1);
        }
    }
}

#assign the reset net name.
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 1) {
    if ($field_name[$i] ne "") {
        $default_reset_net[$i] = sprintf ("%s_default", $field_name[$i]);
    }
}

#*****************************************************
#copy template until generated rtl string is found.
#*****************************************************
$search_string_found = 0;
while (!$search_string_found) {
    $file_line = <TEMPLATE_FILE>;
    if ($file_line =~ /Start Auto generated rtl code/) {
        $search_string_found = 1;
    } else {
        printf CSR_TOP ("%s", $file_line);
    }
    if (eof (TEMPLATE_FILE)) {
        die "Never found the string: \"Start Auto generated rtl code\" in $template_file\n";
    }
}
#*****************************************************
# print two more lines
#*****************************************************
printf CSR_TOP ("%s", $file_line);
$file_line = <TEMPLATE_FILE>;
printf CSR_TOP ("%s", $file_line);

#*****************************************************
#*****************************************************
#START WRITING RTL CODE
#*****************************************************
#*****************************************************

printf CSR_TOP ("   always @(posedge clk_csr) begin\n");
printf CSR_TOP ("      rd_or_wr_r2 <= rd_or_wr_r1;\n");
printf CSR_TOP ("   end\n");

printf CSR_TOP ("   always @(posedge clk_csr) begin\n");
for($i = 0; $i < (2**($addr_hi_bit+1)); $i = $i + 256) {
    $upper = $i/256;
    printf CSR_TOP ("      decode_%02d_8_%02d <= rd_or_wr_r1 & (csr_addr_r1[%02d:08] == %d'h%02X);\n", $addr_hi_bit, $upper, $addr_hi_bit, ($addr_hi_bit - 7), $upper); 
}

printf CSR_TOP ("   end\n");

print CSR_TOP "\n";
print CSR_TOP "// *****************************************************\n";
print CSR_TOP "// RTL for the 5 bit \"register\" decode.\n";
print CSR_TOP "// *****************************************************\n";
printf CSR_TOP ("  always @(posedge clk_csr) ");
printf CSR_TOP ("begin\n");
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    $current_register  = (int ($i / 64) * 8);
    $upper             = (int ($current_register / 256));
    if ($register_name[$i] ne "") {
        $print_net_1 = sprintf("%s_en_r3", $register_name[$i]);
        $print_net_2 = sprintf("rd_or_wr_r2");
        printf CSR_TOP ("      %-35s <= %s & decode_%02d_8_%02d & (csr_addr_r2[07:03] == 5'b%05b); // Decode for register 0x%03x\n", $print_net_1, $print_net_2, $addr_hi_bit, $upper, (int((($current_register) - ((int($current_register / 256)) * 256)) / 8)), $current_register);
    }
}
printf CSR_TOP ("   end\n");

print CSR_TOP "\n";
print CSR_TOP "// *****************************************************\n";
print CSR_TOP "// Start RTL for each bit and assign the 64 bit wire\n";
print CSR_TOP "// *****************************************************\n";
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    $current_register       = (int ($i / 64) * 8);
    $current_group          = (int ($current_register / 256));
    if ($register_name[$i] ne "") {
        printf CSR_TOP ("// ******************************************************\n");
        printf CSR_TOP ("// Register 0x%03x %s\n", $current_register, $register_name[$i]);
        printf CSR_TOP ("// ******************************************************\n");
        for ($j = ($i + 63); $j >= $i; $j--) {
            $current_register       = (int ($j / 64) * 8);
            $current_group          = (int ($current_register / 256));
            $current_bit            = $j - ($current_register * 64/8);
            $hi_field_bit           = ($current_bit - $lo_bit[$j] + $start_bit[$j]);
            $bits_to_next_byte      = $current_bit - ((int ($current_bit/8)) * 8);
            $lo_field_bit           = $hi_field_bit - $bits_to_next_byte;
            if ($lo_field_bit < $start_bit[$j]) {
                $lo_field_bit = $start_bit[$j];
            }
            $j_adjust     = $hi_field_bit - $lo_field_bit;
            $hi_reg_bit   = $current_bit;
            $lo_reg_bit   = $current_bit - $j_adjust;
            $byte_en      = (int ($current_bit/8));

            $reg_we_fp        = "core_reg_we_r3";

            $reset_temp[$j] = $reset_temp[$j];
            $reg_we_fp      = "core_reg_we_r3";

            if ($field_name[$j] ne "") {
                printf CSR_TOP ("// ******************************************************\n");
                printf CSR_TOP ("// Bit(s) %02d:%02d (%s) of Register 0x%03x %s\n", $hi_bit[$j], $lo_bit[$j], $field_name[$j], $current_register, $register_name[$j]);
                printf CSR_TOP ("// ******************************************************\n");
                if ( (($access[$j] eq "RO") | ($access[$j] eq "ROS")) & ($set_term_net_name[$j] eq "") & ($load_term_net[$j] eq "") & ($load_data_net[$j] eq "") ) {
                    if ($number_of_bits[$j] == 1) {
                        printf CSR_TOP ("assign %s_reg = %s;\n", $field_name[$j], $default_reset_net[$j]);
                    } else {
                        printf CSR_TOP ("assign %s_reg[%02d:%02d] = %s[%02d:%02d];\n", $field_name[$j], $hi_field_bit, $lo_field_bit, $default_reset_net[$j], $hi_field_bit, $lo_field_bit);
                    }
                } else {
                    if ($write_rw_rtl[$j]) {                        
                        printf CSR_TOP ("   always @(posedge clk_csr) begin\n");
                        printf CSR_TOP ("      if (~%s) begin\n", $reset_temp[$j]);
                        if ($number_of_bits[$j] == 1) {
                            printf CSR_TOP ("         %s_reg <= %s;\n", $field_name[$j], $default_reset_net[$j]);
                        } else {
                            printf CSR_TOP ("         %s_reg[%02d:%02d] <= %s[%02d:%02d];\n", $field_name[$j], $hi_field_bit, $lo_field_bit, $default_reset_net[$j], $hi_field_bit, $lo_field_bit);
                        }
                        printf CSR_TOP ("      end\n");
                        
                        if (($access[$j] eq "RW") | ($access[$j] eq "RWS")) {
                            printf CSR_TOP ("      else if (%s_en_r3 & %s & byte_en_r3[%d]) begin\n", $register_name[$j], $reg_we_fp, $byte_en);
                            if ($number_of_bits[$j] == 1) {
                                printf CSR_TOP ("         %s_reg <= csr_regwr_data_r3[%02d:%02d];\n", $field_name[$j], $hi_reg_bit, $lo_reg_bit);
                            } else {
                                printf CSR_TOP ("         %s_reg[%02d:%02d] <= csr_regwr_data_r3[%02d:%02d];\n", $field_name[$j], $hi_field_bit, $lo_field_bit, $hi_reg_bit, $lo_reg_bit);
                            }
                            printf CSR_TOP ("      end\n");
                        }
                    } #!$write_rw_rtl
                    if (($access[$j] eq "RSC") || ($access[$j] eq "RS")) {
                        printf CSR_TOP ("     else if ( csr_regwr_data_r3[%02d] & byte_en_r3[%d] & %s_en_r3 & %s & byte_en_r3[%d] & (csr_regwr_data_r3[%02d:%02d] == 5'd%02d)) ", 8, 1, $register_name[$j], $reg_we_fp, 0, 4, 0, $current_bit);
                        printf CSR_TOP ("begin\n");
                        printf CSR_TOP ("         %s_reg <= 1'b1;\n", $field_name[$j]);
                        printf CSR_TOP ("       end\n");
                        
                    }
                    if (($access[$j] eq "RSC") || ($access[$j] eq "RC")) {
                        printf CSR_TOP ("     else if (~csr_regwr_data_r3[%02d] & byte_en_r3[%d] & %s_en_r3 & %s & byte_en_r3[%d] & (csr_regwr_data_r3[%02d:%02d] == 5'd%02d)) ", 8, 1, $register_name[$j], $reg_we_fp, 0, 4, 0, $current_bit);
                        printf CSR_TOP ("begin\n");
                        printf CSR_TOP ("         %s_reg <= 1'b0;\n", $field_name[$j]);
                        printf CSR_TOP ("       end\n");
                    }
                    if (($access[$j] eq "RW1CS") | ($access[$j] eq "RW1C")) {
                        printf CSR_TOP ("     else if ( csr_regwr_data_r3[%02d] & byte_en_r3[%d] & %s_en_r3 & %s) ", $hi_reg_bit, $byte_en, $register_name[$j], $reg_we_fp);
                        printf CSR_TOP ("begin\n");
                        printf CSR_TOP ("         %s_reg <= 1'b0;\n", $field_name[$j]);
                        printf CSR_TOP ("       end\n");
                    }
                    if ($set_term_net_name[$j] ne "") {
                        printf CSR_TOP ("     else if (%s", $set_term_net_name[$j]);
                        
                        if ($freeze_csr_net_name[$j] ne "") {
                            printf CSR_TOP (" & ~%s", $freeze_csr_net_name[$j]);
                        }
                        
                        printf CSR_TOP ") begin\n";
                        printf CSR_TOP ("         %s_reg <= {%s{1'b1}};\n", $field_name[$j], $number_of_bits[$j]);
                        printf CSR_TOP ("       end\n");
                        
                        if ($freeze_csr_net_name[$j] ne "") {
                            printf CSR_TOP ("     else if (~%s & ~%s)", $set_term_net_name[$j], $freeze_csr_net_name[$j]);
                            printf CSR_TOP " begin\n";
                            printf CSR_TOP ("         %s_reg <= {%s{1'b0}};\n", $field_name[$j], $number_of_bits[$j]);
                            printf CSR_TOP ("       end\n");
                        }
                    }
                    if (($load_term_net[$j] ne "") | ($load_data_net[$j] ne "")) {
                        if ($load_term_net[$j] eq "") {
                            print CSR_TOP "     else ";
                        } else {
                            printf CSR_TOP ("     else if (%s) ", $load_term_net[$j]);
                        }
                        printf CSR_TOP ("begin\n");
                        if ($number_of_bits[$j] == 1) {
                            printf CSR_TOP ("         %s_reg <= %s;\n", $field_name[$j], $load_data_net[$j]);
                        } else {
                            printf CSR_TOP ("         %s_reg[%02d:%02d] <= %s[%02d:%02d];\n", $field_name[$j], $hi_field_bit, $lo_field_bit, $load_data_net[$j], $hi_field_bit, $lo_field_bit);
                        }
                        printf CSR_TOP ("       end\n");
                    }
                    printf CSR_TOP ("   end\n");
                    printf CSR_TOP ("\n");
                }
                if ($field_name[$j] ne "") {
                    $j = $j - $j_adjust;
                }
            }
        }

        printf CSR_TOP ("\n");
        print CSR_TOP "// *****************************************************\n";
        print CSR_TOP "// assign the register net to all the bits.\n";
        print CSR_TOP "// *****************************************************\n";
        printf CSR_TOP ("assign %s_wire = {\n", $register_name[$i]);
        for ($j = ($i + 63); $j >= $i; $j--) {
            $current_register       = (int ($j / 64) * 8);
            $current_group          = (int ($current_register / 256));
            $current_bit            = $j - ($current_register * 64/8);

            if ($current_bit != 63) {
                printf CSR_TOP (", ");
            } else {
                printf CSR_TOP ("  ");
            }
            if ($field_name[$j] ne "") {
                if ($number_of_bits[$j] == 1) {
                    $print_net = sprintf("%s_reg", $field_name[$j]);
                } else {
                    $print_net = sprintf("%s_reg[%02d]", $field_name[$j], ($current_bit - $lo_bit[$j] + $start_bit[$j]));
                }
            } else {
                $print_net = "1'b0"
            }
            printf CSR_TOP ("%-35s", $print_net);
            if ($current_bit == 0) {
                printf CSR_TOP ("};");
            }
            if ($current_bit/4 == int ($current_bit / 4)) {
                printf CSR_TOP ("\n");
            }
        }

        $flag = 1;
        for ($j = ($i + 63); $j >= $i; $j--) {
            $current_register       = (int ($j / 64) * 8);
            $current_group          = (int ($current_register / 256));
            $current_bit            = $j - ($current_register * 64/8);

            $full_register_field_name = sprintf ("%s_reg", $field_name[$j]);
            if ($full_register_field_name eq $output_port_name[$j]) {
                printf ("You must choose a diffrent output port name for register 0x%X bit %d\n", $current_register, $current_bit);
                die;
            }
            if ($output_port_name[$j] ne "") {
                if ($flag) {
                    print CSR_TOP "// *****************************************************\n";
                    printf CSR_TOP ("// assign output ports to bits in this register. 0x%02x %s\n", $current_register, $register_name[$j]);
                    print CSR_TOP "// *****************************************************\n";
                    $flag = 0;
                }
                if ($synchronize_to_clock[$j] ne "") {
                    printf CSR_TOP ("fim_resync #(\n");
                    printf CSR_TOP (".SYNC_CHAIN_LENGTH(%d),\n", $pipeline_stages[$j]);
                    printf CSR_TOP (".WIDTH(%d),\n", $number_of_bits[$j]);
                    printf CSR_TOP (".INIT_VALUE(0),\n");
                    printf CSR_TOP (".NO_CUT(0)\n");
                    printf CSR_TOP (") %s_sync (\n", $field_name[$j]);
                    printf CSR_TOP (".clk   (%s),\n", $synchronize_to_clock[$j]);
                    printf CSR_TOP (".reset (~%s),\n", $reset_temp[$j]);
                    printf CSR_TOP (".d     (%s_reg),\n", $field_name[$j]);
                    printf CSR_TOP (".q     (%s)\n", $output_port_name[$j]);
                    printf CSR_TOP (");\n");

                    #printf CSR_TOP ("SYNC_CLK%s %s_ins (.clk%s_clk (clk%s_clk), .pre_sync (%s_reg), .sync (%s));\n", 0, $field_name[$j], 0, 0, $field_name[$j], $output_port_name[$j]);
                } else {
                    if ($pipeline_stages[$j]) {
                        for (my $pl=1;$pl<=$pipeline_stages[$j];$pl++) {
                            if ($number_of_bits[$j] == 1) {
                                printf CSR_TOP ("   logic         %-35s\n", "${output_port_name[$j]}_r$pl\;");
                            } else {
                                printf CSR_TOP ("   logic [%02d:%02d] %-35s\n", ($start_bit[$j] + $number_of_bits[$j] - 1), $start_bit[$j], "${output_port_name[$j]}_r$pl\;");
                            }
                        }
                        printf CSR_TOP ("   always @(posedge clk_csr) begin\n");
                        for (my $pl=1;$pl<=$pipeline_stages[$j];$pl++) {
                            if ($pl == 1) {
                                printf CSR_TOP ("    %s_r%1d <= %s_reg;\n", $output_port_name[$j], $pl, $field_name[$j]);
                            } else {
                                printf CSR_TOP ("    %s_r%1d <= %s_r%1d;\n", $output_port_name[$j], $pl, $output_port_name[$j], ($pl-1));
                            }
                        }
                        printf CSR_TOP ("   end\n");



                        printf CSR_TOP ("  assign %s = %s_r%1d;\n", $output_port_name[$j], $output_port_name[$j], $pipeline_stages[$j]);
                    } else {
                        printf CSR_TOP ("  assign %s = %s_reg;\n", $output_port_name[$j], $field_name[$j]);
                    }
                }
            }
            if ($number_of_bits[$j] ne "") {
                $j = $j - ($number_of_bits[$j] - 1);
            }
        }
        
        #create pulse for output ports in this register.
        $flag = 1;
        for ($j = ($i + 63); $j >= $i; $j--) {
            $current_register       = (int ($j / 64) * 8);
            $current_group          = (int ($current_register / 256));
            $current_bit            = $j - ($current_register * 64/8);
            $hi_field_bit           = ($current_bit - $lo_bit[$j] + $start_bit[$j]);
            $bits_to_next_byte      = $current_bit - ((int ($current_bit/8)) * 8);
            $lo_field_bit           = $hi_field_bit - $bits_to_next_byte;
            if ($lo_field_bit < $start_bit[$j]) {
                $lo_field_bit = $start_bit[$j];
            }
            $j_adjust = $hi_field_bit - $lo_field_bit;
            $hi_reg_bit = $current_bit;
            $lo_reg_bit = $current_bit - $j_adjust;
            $byte_en = (int ($current_bit/8));
            
            $reg_we_fp    = "core_reg_we_r3";
            
            if ($set_pulse_port_name[$j] ne "") {
                if ($number_of_bits[$j] == 1) {
                    if ($flag) {
                        print CSR_TOP "\n";
                        print CSR_TOP "   // *****************************************************\n";
                        printf CSR_TOP ("   // Create pulse for output ports in this register. 0x%02x %s\n", $current_register, $register_name[$j]);
                        print CSR_TOP "   // *****************************************************\n";
                        $flag = 0;
                    }
                    printf CSR_TOP ("   always @(posedge clk_csr) begin\n");
                    printf CSR_TOP ("      %s <= %s_en_r3 & %s & byte_en_r3[%d] & csr_regwr_data_r3[%02d];\n", $set_pulse_port_name[$j], $register_name[$j], $reg_we_fp, $byte_en, $lo_reg_bit);
                    printf CSR_TOP ("   end\n");

                    for (my $pl=1;$pl<=$pipeline_stages[$j];$pl++) {
                        printf CSR_TOP ("   logic         %-35s\n", "${set_pulse_port_name[$j]}_r$pl\;");
                    }
                    printf CSR_TOP ("   always @(posedge clk_csr) begin\n");
                    for (my $pl=1;$pl<=$pipeline_stages[$j];$pl++) {
                        if ($pl == 1) {
                            printf CSR_TOP ("    %s_r%1d <= %s;\n", $set_pulse_port_name[$j], $pl, $set_pulse_port_name[$j]);
                        } else {
                            printf CSR_TOP ("    %s_r%1d <= %s_r%1d;\n", $set_pulse_port_name[$j], $pl, $set_pulse_port_name[$j], ($pl-1));
                        }
                    }
                    printf CSR_TOP ("   end\n");
                    
                    if ($pipeline_stages[$j]) {
                        printf CSR_TOP ("   assign %s = %s_r%1d;\n", "o_$set_pulse_port_name[$j]", $set_pulse_port_name[$j], $pipeline_stages[$j]);
                    } else {
                        printf CSR_TOP ("   assign %s = %s;\n", "o_$set_pulse_port_name[$j]", $set_pulse_port_name[$j]);
                    }
                } else {
                    print "The set pulse output can only be a 1 bit wide field\n";
                    die;
                }
            }
            if ($number_of_bits[$j] ne "") {
                $j = $j - ($number_of_bits[$j] - 1);
            }
        }
        printf CSR_TOP ("\n");
    }
}

print CSR_TOP "// *****************************************************\n";
print CSR_TOP "// RTL for the first level muxes.\n";
print CSR_TOP "// *****************************************************\n";

printf CSR_TOP ("  always @(posedge clk_csr) ");
printf CSR_TOP ("begin\n");
printf CSR_TOP ("      csr_decode_mux_r4 <= 64'h00000000 // 0x%03x\n", $current_register);
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    $current_register       = (int ($i / 64) * 8);
    if ($register_name[$i] ne "") {
        printf CSR_TOP ("            | %-35s & %-35s // 0x%03x\n", "$register_name[$i]\_wire", "\{64\{$register_name[$i]\_en_r3\}\}", $current_register);
    }
}
printf CSR_TOP ("              ;\n");
printf CSR_TOP ("    end\n");
printf CSR_TOP ("\n");


print CSR_TOP "// *****************************************************\n";
print CSR_TOP "// Now onto everything on the clk clock domain.\n";
print CSR_TOP "// *****************************************************\n";

print CSR_TOP "   // *****************************************************\n";
print CSR_TOP "   // RTL for the final read mux (just an or gate) async signals masked by targeting_clkX_domain_register\n";
print CSR_TOP "   // *****************************************************\n";

#########################################################################
### The net "csr_readdata" below connects to a net in the template !! ###
#########################################################################
printf CSR_TOP ("   always @(posedge clk_csr) begin\n");
printf CSR_TOP ("      csr_readdata <= %-75s; // 0x%03x;\n", "csr_decode_mux_r4", $current_register);
printf CSR_TOP ("   end\n");
printf CSR_TOP ("\n");

# The last thing we must do...
while (<TEMPLATE_FILE>) {
    $file_line = $_;
    printf CSR_TOP ("%s", $file_line);
}

close (TEMPLATE_FILE);

open (RB_SPEC, "> $spec_file")        || die "Can't open output file for output: $spec_file\n";

#*****************************************************
#write to an information file
#*****************************************************
print RB_SPEC "<html>\n";
print RB_SPEC "<head>\n";
print RB_SPEC "<style>\n";
print RB_SPEC "<!--\n";
#*****************************************************
# Define the three Styles We will be using.
#*****************************************************
print RB_SPEC " /* Style Definitions */\n";
print RB_SPEC "p.Body, li.Body, div.Body\n";
print RB_SPEC "        {mso-style-name:Body;\n";
print RB_SPEC "         margin-right:0in;\n";
print RB_SPEC "         mso-margin-top-alt:auto;\n";
print RB_SPEC "         mso-margin-bottom-alt:auto;\n";
print RB_SPEC "         margin-left:0in;\n";
print RB_SPEC "         mso-pagination:widow-orphan;\n";
print RB_SPEC "         font-size:10.0pt;\n";
print RB_SPEC "         mso-bidi-font-size:12.0pt;\n";
print RB_SPEC "         font-family:Arial;\n";
print RB_SPEC "         mso-fareast-font-family:\"Times New Roman\";\n";
print RB_SPEC "         mso-bidi-font-family:\"Times New Roman\";}\n";
print RB_SPEC "p.bitdef, li.bitdef, div.bitdef\n";
print RB_SPEC "         {mso-style-name:bitdef;\n";
print RB_SPEC "         margin-top:5.0pt;\n";
print RB_SPEC "         margin-right:0in;\n";
print RB_SPEC "         margin-bottom:5.0pt;\n";
print RB_SPEC "         margin-left:0.6in;\n";
print RB_SPEC "         text-indent:-.5in;\n";
print RB_SPEC "         mso-pagination:widow-orphan;\n";
#print RB_SPEC "         tab-stops:.75in\n";
print RB_SPEC "         font-size:10.0pt;\n";
print RB_SPEC "         font-family:\"Arial\";\n";
print RB_SPEC "         mso-fareast-font-family:\"Arial\";}\n";
print RB_SPEC "p.bitdes, li.bitdes, div.bitdes\n";
print RB_SPEC "         {mso-style-name:bitdes;\n";
print RB_SPEC "         margin-top:5.0pt;\n";
print RB_SPEC "         margin-right:0in;\n";
print RB_SPEC "         margin-bottom:5.0pt;\n";
print RB_SPEC "         margin-left:0.8in;\n";
print RB_SPEC "         mso-pagination:widow-orphan;\n";
print RB_SPEC "         font-size:10.0pt;\n";
print RB_SPEC "         font-family:\"Arial\";\n";
print RB_SPEC "         mso-fareast-font-family:\"Arial\";}\n";
print RB_SPEC "p.left, li.left, div.left\n";
print RB_SPEC "        {mso-style-name:left;\n";
print RB_SPEC "         margin:0in;\n";
print RB_SPEC "         margin-bottom:.0001pt;\n";
print RB_SPEC "         text-align:right;\n";
print RB_SPEC "         mso-pagination:widow-orphan;\n";
print RB_SPEC "         font-size:10.0pt;\n";
print RB_SPEC "         mso-bidi-font-size:12.0pt;\n";
print RB_SPEC "         font-family:Arial;\n";
print RB_SPEC "         mso-fareast-font-family:\"Times New Roman\";\n";
print RB_SPEC "         mso-bidi-font-family:\"Times New Roman\";}\n";
print RB_SPEC "-->\n";
print RB_SPEC "</style>\n";

print RB_SPEC "<style type=\"text/css\">\n";
#print RB_SPEC "table          {border:ridge 5px blue;}\n";
#print RB_SPEC "table td       {border:inset 1px \#000;}\n";
print RB_SPEC "table tr#BLUE  {background-color:blue; color:white;}\n";
print RB_SPEC "</style>\n";

print RB_SPEC "</head>\n";
print RB_SPEC "<body>\n";
#debug prints for charactor spacing
print RB_SPEC "\n";
#print RB_SPEC "00000000011111111112222222222333333333344444444445555555555666666666677777777778\n";
#print RB_SPEC "12345678901234567890123456789012345678901234567890123456789012345678901234567890\n";


#*****************************************************
#Start
#*****************************************************

printf RB_SPEC ("<h1>Intel Confidential</h1>\n");
printf RB_SPEC ("<h2>$project_name Configuration Registers</h2>\n");

#*****************************************************
#Make a table of all the registers.
#*****************************************************
printf RB_SPEC  ("<table BORDER>\n");
printf RB_SPEC ("<tr> <td><b>Register</b></td> <td><b>Offset</b></td></tr>\n");
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    $current_register       = (int ($i / 64) * 8);
    if ($register_name[$i] ne "") {
        #print RB_SPEC "\n";
        if ($dont_spec[$i]) {
            printf RB_SPEC  ("<tr> <td>%s</td> <td>0x%03X</td> </tr>\n", $register_name[$i], $current_register);
        } else {
            printf RB_SPEC  ("<tr> <td>%s</td> <td><a href=\"#r0x%03X\">0x%03X</a></td> </tr>\n", $register_name[$i], $current_register, $current_register);
        }
    }
}
printf RB_SPEC  ("</table>\n");

printf RB_SPEC  ("<p><b>Table of all registers:</b></p>");

#*****************************************************
#Write the register specification
#*****************************************************
printf RB_SPEC  ("<table BORDER>\n"); # **************************
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    $current_register       = (int ($i / 64) * 8);
    if ($register_name[$i] ne "") {
        print RB_SPEC "\n";
        printf RB_SPEC  ("<tr id=\"BLUE\"><td><a NAME=\"r0x%03X\"</a><b>%s</b></td><td><b>0x%03X</b></td><td>%s</td><td>%s</td><td>%s</td></tr>\n", $current_register, $register_name[$i], $current_register, "", "", "");
        #Insert here

        printf RB_SPEC  ("<tr> <td><b>Register</b></td> <td><b>Bits</b></td> <td><b>Access</b></td> <td><b>Reset</b></td> <td><b>Description</b></td> </tr>\n");
        printf RB_SPEC  ("<tr> "); # ...

        for ($j = ($i + 63); $j >= $i; $j--) { # run through the bits in this regidter (j is modified)
            $current_register       = (int ($j / 64) * 8);
            $current_group          = (int ($current_register / 256));
            $current_bit            = $j - ($current_register * 64/8);
            if ( ($reset_temp[$j] eq "rst_n_csr") || ($reset_temp[$j] eq "clk0_rst_c_w_n") || ($reset_temp[$j] eq "clk1_rst_c_w_n") ) {
                $reset_temp_fs = "warm or cold";
            } else {
                $reset_temp_fs = "cold";
            }

            # %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ($field_name[$j] ne "") { # If this bit is not reserved...
                if ($number_of_bits[$j] == 1) { # if it is a one bit vector
                    printf RB_SPEC  ("<td><b>%s</b></td> <td><b>%d</b></td> <td>%s</td>", $field_name[$j], $lo_bit[$j], $access[$j]);
                } else { # else it is a two or more bit vector...
                    printf RB_SPEC  ("<td><b>%s</b>[%02d:%02d]</td> <td><b>%02d:%02d</b></td> <td>%s</td>", $field_name[$j], ($start_bit[$j] + $number_of_bits[$j] - 1), $start_bit[$j], $hi_bit[$j], $lo_bit[$j], $access[$j]);
                }

                if ( (($access[$j] eq "RO") | ($access[$j] eq "ROS")) & ($set_term_net_name[$j] eq "") && ($load_term_net[$j] eq "") ) {
                    printf RB_SPEC ("<td>0x%X</td>", $reset_value[$j]);
                } elsif ( (($access[$j] eq "RO") | ($access[$j] eq "ROS")) | ($reset_temp[$j] eq "1'b1")) {
                    printf RB_SPEC ("<td>NA</td>");
                } else {
                    printf RB_SPEC ("<td>%s 0x%X</td>", $reset_temp_fs, $reset_value[$j]);
                }

                printf RB_SPEC ("<td>");
                if ($description_of_field[$j] ne "") {
                    printf RB_SPEC ("%s", $description_of_field[$j]);
                }
                if ($set_pulse_port_name[$j] ne "") {
                    printf RB_SPEC (" Hardware creates a pulse when this bit is set (by SW) on the internal ASIC net %s.\n", $set_pulse_port_name[$j]);
                }
                if ($freeze_csr_net_name[$j] ne "") {
                    printf RB_SPEC (" HW Effects on this register are blocked when the internal ASIC net; %s is false.\n", $freeze_csr_net_name[$j]);
                }
                printf RB_SPEC ("</td>");

                # adjust $j for next bit (after this vector)
                $j = $j - ($number_of_bits[$j] - 1);
                printf RB_SPEC  (" </tr>\n"); # Done with row entry

            } else { # it is a reserved bit -OR- the ENTIRE register is not defined
                # Now, figure out how long these reserved bits go on so we can print only one line into the spec...
                $hi_bit[$j] = $current_bit;
                $continue_loop = 1;
                for ($k = $j; $continue_loop; $k--) {
                    $current_register       = (int ($k / 64) * 8);
                    $current_bit            = $k - ($current_register * 64/8);
                    if ($field_name[$k] ne "") {
                        $k++;
                        $continue_loop = 0;
                    }
                    if ($current_bit == 0) {
                        $continue_loop = 0;
                    }
                }
                $k = $k + 1; #this puts $k at the last reserved bit
                $current_register       = (int ($k / 64) * 8);
                $current_bit            = $k - ($current_register * 64/8);
                for ($l = $k; $l <= $j; $l++) { # fill all the bits with the width
                    $number_of_bits[$l] = $j - ($k - 1);
                }
                $lo_bit[$j] = $current_bit;
                if ($number_of_bits[$j] == 1) { # if it is a one bit vector
                    printf RB_SPEC ("<tr> <td>reserved</td> <td>%02d</td> <td>RsvdZ</td> <td>0</td> <td> </td> </tr>", $lo_bit[$j]);
                } else {
                    printf RB_SPEC ("<tr> <td>reserved</td> <td>%02d:%02d</td> <td>RsvdZ</td> <td>0</td> <td> </td> </tr>", $hi_bit[$j], $lo_bit[$j]);
                }
                $j = $j - ($number_of_bits[$j] - 1);
            }
        }
        print RB_SPEC "<tr>  <td>| </td>  <td> </td>  <td> </td>  <td>  </td>  <td> </td> </tr>\n";
    }
}
printf RB_SPEC  ("</table>\n"); # ***************************************
print RB_SPEC "</body>\n";
print RB_SPEC "</html>\n";

close (RB_SPEC);

# *****************************
# *** Now write an XML file ***
# *****************************

open (XML_FILE, "> $xml_file")        || die "Can't open output file for output: $xml_file\n";

print XML_FILE "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
print XML_FILE "<component>\n";
print XML_FILE "<name>prreg</name>\n";
print XML_FILE "<vendor>fpga</vendor>\n";
print XML_FILE "<version>1.0</version>\n";
print XML_FILE "<library>fpga_lib</library>\n";
print XML_FILE "        <memoryMaps>\n";
print XML_FILE "                <memoryMap>\n";
print XML_FILE "                        <name>$project_name</name>\n";
print XML_FILE "                        <addressBlock>\n";
#print XML_FILE "               <name>REMOVEIT</name>\n";
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    $current_register       = (int ($i / 64) * 8);
    if ($register_name[$i] ne "") {
        print XML_FILE "                                <register>\n";
        print XML_FILE "                                        <name>$register_name[$i]</name>\n";
        printf XML_FILE ("                                        <addressOffset>0x%X</addressOffset>\n", $current_register);
        print XML_FILE "                                        <size>64</size>\n";
        print XML_FILE "                                        <lock></lock>\n";
        print XML_FILE "                                        <description>$register_name[$i]</description>\n";
        print XML_FILE "                                        <reset>\n";
        printf XML_FILE ("                                                <value>0x%016X</value>\n", $reset_value_64[$i]);
        print XML_FILE "                                        </reset>\n";

        print XML_FILE "\n";
        
        for ($j = ($i + 63); $j >= $i; $j--) { # run through the bits in this register (NOTE!!! j is modified)
            if ($field_name[$j] ne "") { # If this bit is not reserved...
                print XML_FILE "                                        <field>\n";
                print XML_FILE "                                                <name>$field_name[$j]</name>\n";
                print XML_FILE "                                                <bitOffset>$lo_bit[$j]</bitOffset>\n";
                printf XML_FILE ("                                                <reset>0x%X</reset>\n",$reset_value[$j]);
                print XML_FILE "                                                <bitWidth>$number_of_bits[$j]</bitWidth>\n";
                print XML_FILE "                                                <access>$access[$j]</access>\n";
                print XML_FILE "                                                <description>$description_of_field[$j]</description>\n";
                print XML_FILE "                                        </field> \n";
                
                
                # adjust $j for next bit (after this vector)
                $j = $j - ($number_of_bits[$j] - 1);
                
            } else { # it is a reserved bit -OR- the ENTIRE register is not defined
                # Now, figure out how long these reserved bits go on so we can print only one line into the spec...
                $hi_bit[$j] = $current_bit;
                $continue_loop = 1;
                for ($k = $j; $continue_loop; $k--) {
                    $current_register       = (int ($k / 64) * 8);
                    $current_bit            = $k - ($current_register * 64/8);
                    if ($field_name[$k] ne "") {
                        $k++;
                        $continue_loop = 0;
                    }
                    if ($current_bit == 0) {
                        $continue_loop = 0;
                    }
                }
                $k = $k + 1; #this puts $k at the last reserved bit
                $current_register       = (int ($k / 64) * 8);
                $current_bit            = $k - ($current_register * 64/8);
                for ($l = $k; $l <= $j; $l++) { # fill all the bits with the width
                    $number_of_bits[$l] = $j - ($k - 1);
                }
                $lo_bit[$j] = $current_bit;
                
                print XML_FILE "                                        <field>\n";
                print XML_FILE "                                                <name>Reserved$lo_bit[$j]</name>\n";
                print XML_FILE "                                                <bitOffset>$lo_bit[$j]</bitOffset>\n";
                print XML_FILE "                                                <reset>0x0</reset>\n";
                print XML_FILE "                                                <bitWidth>$number_of_bits[$j]</bitWidth>\n";
                print XML_FILE "                                                <access>RsvdZ</access>\n";
                print XML_FILE "                                                <description>Reserved</description>\n";
                print XML_FILE "                                        </field> \n";
                
                $j = $j - ($number_of_bits[$j] - 1);
            }
        }
        print XML_FILE "                                </register>\n";
    }
}

print XML_FILE "                        </addressBlock>\n";
print XML_FILE "                </memoryMap>\n";
print XML_FILE "        </memoryMaps>\n";
print XML_FILE "</component>\n";

close (XML_FILE);



#*****************************************************
#Write the C struct...
#*****************************************************
#open (NT_DEF, "> ${rtl_dir}nt_defines.txt");
#printf NT_DEF ("#include <pshpack1.h>\n");
#printf NT_DEF ("typedef struct $project_name_BAR0_REGISTERS {\n");

$rp = 0;
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 64) {
    $current_register       = (int ($i / 64) * 8);
    $bp = 0;
    if ($register_name[$i] ne "") { # if the register is defined...
        #printf NT_DEF ("\n");
        #printf NT_DEF ("   union { // 0x%03X\n", $current_register);
        #printf NT_DEF ("      struct {\n");
        for ($j = $i; ($j <= ($i + 63)); $j++) { # run through the bits in this field
            $current_register       = (int ($j / 64) * 8);
            $current_group          = (int ($current_register / 256));
            $current_bit            = $j - ($current_register * 64/8);

            if ($field_name[$j] ne "") { # If this bit is not reserved...
                $uc_print = $field_name[$j];
                while ($uc_print =~ /^(.*)_(.*)$/) {
                    $uc_print = $1.ucfirst $2;
                }
                $uc_print = ucfirst $uc_print;
                $uc_print = sprintf ("int %s : %0d;", $uc_print, $number_of_bits[$j]);
                #printf NT_DEF ("         %-35s // Bits %.2d-%.2d (%s) %s\n", $uc_print, $hi_bit[$j], $lo_bit[$j], $access[$j], $field_name[$j]);

                # adjust $j for next bit (after this vector)
                $j = $j + ($number_of_bits[$j] - 1);
            } else { # it is a reserved bit.
                $uc_print = sprintf ("int %s%d : %0d;", "BitPad", $bp, $number_of_bits[$j]);
                #printf NT_DEF ("         %s\n", $uc_print);
                $bp++;
                $j = $j + ($number_of_bits[$j] - 1);
            }
        }
        #printf NT_DEF ("      } bits;\n");
        #printf NT_DEF ("      int v;\n");
        $uc_print = $register_name[$i];
        while ($uc_print =~ /^(.*)_(.*)$/) {
            $uc_print = $1.ucfirst $2;
        }
        $uc_print = ucfirst $uc_print.";";
        #printf NT_DEF ("   } %-10s // 0x%03X %s\n", $uc_print, $current_register, $register_name[$i]);
    } else { # the register is spare
        $uc_print = "RegPad$rp;";
        #printf NT_DEF ("   int %-10s // 0x%03X Reserved Register\n", $uc_print, $current_register);
        $rp++;
    }
}
#printf NT_DEF ("} $project_name_BAR0_REGISTERS;\n");
#printf NT_DEF ("#include <poppack.h>\n");
#close (NT_DEF);

#open (CSV_FILE, "> ${rtl_dir}csr_regs.csv");
#open (NT_CSV_FILE, "> ${rtl_dir}nt_csr_regs.csv");
#*****************************************************
# Make a csv file...
#*****************************************************
for($i = 0; $i < ((2**($addr_hi_bit+1)) * 64/8); $i = $i + 1) {
    $current_register       = (int ($i / 64) * 8);
    $current_group          = (int ($current_register / 256));
    $current_bit            = $i - ($current_register * 64/8);
    if ( ($reset_temp[$i] eq "rst_n_csr") || ($reset_temp[$i] eq "clk0_rst_c_w_n") || ($reset_temp[$i] eq "clk1_rst_c_w_n") ) {
        $tmp_print = "W_C";
    } else {
        $tmp_print = "C";
    }

    #printf CSV_FILE ("0x%03X,%.2d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,0x%X,%s,\n", $current_register, $current_bit, $group_name[$i], $group_name[$i], $register_name[$i], $register_name[$i], $field_name[$i], $field_name[$i], $number_of_bits[$i], $hi_bit[$i], $lo_bit[$i], $start_bit[$i], 0, $tmp_print, $reset_value[$i], $access[$i]);

    $register_print = $register_name[$i];
    while ($register_print =~ /^(.*)_(.*)$/) {
        $register_print = $1.ucfirst $2;
    }
    $register_print = ucfirst $register_print;

    $bit_print = $field_name[$i];
    while ($bit_print =~ /^(.*)_(.*)$/) {
        $bit_print = $1.ucfirst $2;
    }
    $bit_print = ucfirst $bit_print;

    #printf NT_CSV_FILE ("0x%03X,%.2d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,0x%X,%s,\n", $current_register, $current_bit, 0, $group_name[$i], $register_print, $register_name[$i], $bit_print, $field_name[$i], $number_of_bits[$i], $hi_bit[$i], $lo_bit[$i], $start_bit[$i], 0, $tmp_print, $reset_value[$i], $access[$i]);


}
#close (NT_CSV_FILE);


#CSV Columns:
#01. Register Offset (In hex)
#02. Bit number in the register (In decimal).
#03. $group_name[$i]         = Abbreviated group name. If NULL in the first register in the group, this is a reserved group. 1XX 2XX 3XX 4XX is groups.
#04. $group_name[$i]         = Verbose group name.
#05. $register_name[$i]      = Abbreviated register name. If NULL it is a reserved register.
#06. $register_name[$i]      = Verbose register name.
#07. $field_name[$i]           = Abbreviated bit(s) name. If NULL it is a reserved bit.
#08. $field_name[$i]           = Verbose bit name.
#09. $number_of_bits[$i]     = The number of bits this field is wide. (simply ($hi_bit - $lo_bit) + 1)
#10. $hi_bit[$i]             = The High bit in the 64 bit register.
#11. $lo_bit[$i]             = The Low  bit in the 64 bit register.
#12. $start_bit[$i]          = Describes how to number within a field, this has nothing to do with the bit number in the register.
#                              (Example: for address[43:32] this column would be 32. address 32:02, a 02, 16:00 a 00...)
#13. $clk_domain[$i]         = 1 = CLK clock domain, 0 = Core_clock domain. (if = 1, reset to default on SHPC Bus-speed-mode-change)
#14. $reset_temp[$i]         = C = Set to default on Cold reset. W_C = Set to default on Warm or Cold reset.
#15. $reset_value[$i]        = The Default value (In HEX).
#16. $access[$i]             = RO, RW, RSC, RC, RS or RW1CS.

# Notes:
# When parsing through this CSV file, when you hit a register bit filed
# and the width of this filed is greater then one (number_of_bits > 1),
# there is no reason to pars the rest of the bit field because all the
# bits in the field will have identical information.

# The hi_bit and lo_bit columns are in fact valid on reserved bits. They
# mark the first and last consecutive reserved bits.

sub add_zeros {
    my $str = shift(@_);
    my $len = shift(@_);
    my $nob = shift(@_);
    return ($str);
}
