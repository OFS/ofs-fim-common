#!/bin/bash
# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: MIT

set -eux

sed -i -e '/INCLUDE_HSSI/d' *.qsf 
