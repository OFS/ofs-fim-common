# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

define_project $::env(Q_PROJECT)

define_base_revision $::env(Q_REVISION)


# Only set this for pr compile, not for FIM compile
if { [info exists ::env(PR_COMPILE)] } {
    if { $::env(PR_COMPILE) == "1" } {
        define_pr_impl_partition -impl_rev_name $::env(Q_PR_REVISION) -partition_name $::env(Q_PR_PARTITION_NAME)
    }
}
