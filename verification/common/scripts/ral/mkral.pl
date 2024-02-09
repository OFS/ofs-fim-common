#!/usr/bin/perl -w
# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: MIT

#
#

my $f1 = shift || die "Usage: mkral.pl <XLS file name w/o extention> <register block name> <[block size] | default 8> \n";
my $f2 = shift;
my $f3 = shift || "8";

die "Usage: mkral.pl <XLS file name w/o extention> <register block name> <[block size] | default 8> \n" unless (-e "$f1.xls");

print "Processing - $f1 into ral_$f2.sv RAL file \n";


system("xls2xml.pl $f1.xls $f2; \
        ralgen -uvm -ipxact2ralf $f1.xml -t $f2; \
        perl -p -i.bak -e \"s/system/block/\" $f1.ralf;
        perl -p -i.bak -e \"s/^    bytes 4/    bytes $f3/\" $f1.ralf;
        perl -p -i.bak -e \"s/^.*REMOVEIT.*//\" $f1.ralf;
        perl -p -i.bak -e \"s/^}//\" $f1.ralf; \
        ralgen -uvm  $f1.ralf -t $f2;" );

