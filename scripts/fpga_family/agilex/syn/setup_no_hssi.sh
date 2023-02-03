#!/bin/bash

set -eux

sed -i -e '/INCLUDE_HSSI/d' *.qsf 
