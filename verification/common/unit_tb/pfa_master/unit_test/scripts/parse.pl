#!/usr/bin/env perl
# Copyright 2021 Intel Corporation
# SPDX-License-Identifier: MIT

use strict;
use warnings;

open(FILE, "sim.log");   # Open handle to input file 

if (grep{/ERROR/} <FILE>) {
  print "\n\n****** Test Failed! ******\n\n";
}
else {
  print "\n\n****** Test Passed ******\n\n";
}

close FILE;
