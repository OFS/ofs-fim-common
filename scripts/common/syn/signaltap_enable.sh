#!/bin/bash

# This script is to enable signaltap build
# 
echo signaltap_enable.sh OFS_BOARD_VARIANT = $OFS_BOARD_VARIANT
echo OFS_PROJECT = $OFS_PROJECT
echo WORK_SYN_TOP_PATH = $WORK_SYN_TOP_PATH
case $OFS_PROJECT in
    d5005)
        sed -i "s/ENABLE_SIGNALTAP OFF/ENABLE_SIGNALTAP ON/g" $WORK_SYN_TOP_PATH/d5005.qsf
    ;;
    n6000)
        echo signaltap for $OFS_PROJECT 
        #sed -i "s/ENABLE_SIGNALTAP OFF/ENABLE_SIGNALTAP ON/g" $WORK_SYN_TOP_PATH/???.qsf
    ;;
esac
