#!/usr/bin/env perl
# Copyright (C) 2015 Intel Corporation
# SPDX-License-Identifier: MIT

use warnings;
use strict;
use Spreadsheet::ParseExcel;

# Check for right command-line arguments
my $num_cmdargs = @ARGV;
die "ERROR: An incorrect number of arguments was specified.\nUsage: $0 <filename.xls>\n" if ($num_cmdargs < 1);
my $xls_file = $ARGV[0];
my $block_name = $ARGV[1];
$xls_file =~ /\./;
my $xml_file = "$`.xml";

# Read in workbook/sheets
my $parser = Spreadsheet::ParseExcel -> new();
my $workbook = $parser->Parse($xls_file) || die "Can't read spreadsheet $xls_file!\n";
my $ws_regflds = $workbook->Worksheet('reg_fields'); 
open (XML_FILE, "> $xml_file") || die "Can't open $xml_file file!\n";;

print_HEADER();
# Iterate over the range of populated rows
my $ws_row = 0; 
my $num_regs = 0;
while ($ws_row < $ws_regflds->{MaxRow})
{
    # Matches the beginning of a register definition 
    if ($ws_regflds->{Cells}[$ws_row][0]->Value =~ "FIELD NAME")
    {
        $ws_row--;
        print_reg ($ws_row);
        $ws_row = $ws_row + 2;
        # Matches the end of a register definition 
        while ($ws_regflds->{Cells}[$ws_row][0]->Value)
        {
            print_field($ws_row);
            $ws_row++; 
        }
        indent(4,"</register>");
    }
    $ws_row++;
}
print_FOOTER();

close XML_FILE;

# Print some statistics
$ws_row--;
print "Processed $ws_row rows from XLS file\n";
print "Identified $num_regs registers\n";
print "\n";

# --------------------- SUBROUTINES --------------------- 

# This function prints the information of a register in a row of the XLS file, to the XML file
sub print_reg
{
    $num_regs++;
    my $row = shift(@_);
    my $name = $ws_regflds->{Cells}[$row][0]->Value;
    my $addr = $ws_regflds->{Cells}[$row][1]->Value;
    my $lock = $ws_regflds->{Cells}[$row][2]->Value;
    my $desc = $ws_regflds->{Cells}[$row][4]->Value;
    my $rval = $ws_regflds->{Cells}[$row][3]->Value;
    my $size = (length($rval)-2)*4;     # subtracting 2 due to "0x"

    indent(4,"<register>");
    indent(5,"<name>$name</name>");
    indent(5,"<addressOffset>$addr</addressOffset>");
    indent(5,"<size>$size</size>");
    indent(5,"<lock>$lock</lock>");
    indent(5,"<description>$desc</description>");
    indent(5,"<reset>");
    indent(6,"<value>$rval</value>");
    indent(5,"</reset>");
}

# This function prints the information of a field in a row of the XLS file, to the XML file
sub print_field
{
    my $offs; my $wdth;
    my $row = shift(@_);
    my $name = $ws_regflds->{Cells}[$row][0]->Value;
    my $rval = $ws_regflds->{Cells}[$row][3]->Value;
    my $accs = $ws_regflds->{Cells}[$row][2]->Value;
    my $desc = $ws_regflds->{Cells}[$row][4]->Value;
    my $bits = $ws_regflds->{Cells}[$row][1]->Value;
    # Extract the bit offset and width from bits range
    $bits =~ s/\[//; $bits =~ s/\]//;
    if ($bits =~ /:/)
    {
        $offs = $';
        $wdth = 1 + $` - $';
    }
    else
    {
        $offs = $bits;
        $wdth = 1;
    }

    indent(5,"<field>");
    indent(6,"<name>$name</name>");
    indent(6,"<bitOffset>$offs</bitOffset>");
    indent(6,"<reset>$rval</reset>");
    indent(6,"<bitWidth>$wdth</bitWidth>");
    decode_accs_type(6, $accs);
    indent(6,"<description>$desc</description>");
    indent(5,"</field>");
}

# Prints the access type and write modifier based on the access type
sub decode_accs_type
{
    my $tabs   = shift(@_);
    my $accs   = shift(@_);
    # Table for access types
    if    ($accs =~ "RO")
        {
            indent($tabs,"<access>read-only</access>");
        }
    elsif ($accs =~ "RW")
        {
            indent($tabs,"<access>read-write</access>");

            if ($accs =~ "RWS")
            {
                indent($tabs,"<sticky>true</sticky>");
            }
            else
            {
                if ($accs =~ "1C")
                {
                    indent($tabs,"<modifiedWriteValue>oneToClear</modifiedWriteValue>");
                }
                elsif ($accs =~ "1S")
                {
                    indent($tabs,"<modifiedWriteValue>oneToSet</modifiedWriteValue>");
                }
            }

            if ($accs =~ "L")
            {
                indent($tabs,"<lock>true</lock>");
            }
       }
    elsif ($accs =~ "WO")
        {
            indent($tabs,"<access>write-only</access>");
        }
    elsif ($accs =~ "W1")
        {
            indent($tabs,"<access>write-once</access>");
        }
    elsif ($accs =~ "RsvdP")
        {
            indent($tabs,"<access>write-only</access>");
        }
    elsif ($accs =~ "RsvdZ")
        {
            indent($tabs,"<access>write-only</access>");
        }
    else
        {
            my $row = $ws_row + 1;
            print "Undefined register access type \"$accs\" in line $row\n"
        }
}

# This function indents a string by the specified number of tabs
sub indent
{
    my $num_tab = shift(@_);
    for (my $i=0; $i < $num_tab; $i++) {print XML_FILE "\t";}
    print XML_FILE "@_\n";
}

# This function prints the IP-XACT header lines
sub print_HEADER
{
    indent(0,'<?xml version="1.0" encoding="utf-8"?>');
    indent(0,"<component>");
    indent(0,"<name>prreg</name>");
    indent(0,"<vendor>fpga</vendor>");
    indent(0,"<version>1.0</version>");
    indent(0,"<library>fpga_lib</library>");
    indent(1,"<memoryMaps>");
    indent(2,"<memoryMap>");
    indent(2,"<name>$block_name</name>");
    indent(3,"<addressBlock>");
    indent(2,"<name>REMOVEIT</name>");
}

# This function prints the IP-XACT footer lines
sub print_FOOTER
{
    indent(3,"</addressBlock>");
    indent(2,"</memoryMap>");
    indent(1,"</memoryMaps>");
    indent(0,"</component>");
}


