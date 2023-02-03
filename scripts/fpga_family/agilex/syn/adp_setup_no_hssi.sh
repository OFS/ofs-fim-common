#!/bin/bash

set -eux

sed -i -e '/INCLUDE_HSSI/d' \
       -e '/INCLUDE_HSSI_AND_NOT_CVL/d' *.qsf 
