#!/bin/bash
# This script generates simulation rtl for all IPs in the Agilex OFS design using the IP list file . The RTL would be generated at the location where a particular IP resides.
# After generating all RTL, the script calls the gen_sim_flist.sh script to automatically generate the simulation flist that will be used in simulation
# Make sure you have the right environment sourced before you run this script.

usage()
{
   echo "Usage: sh gen_sim_files.sh <target(s)> <device (optional)> <family (optional)>"
   echo " The script generates HDL for simulation of different FIM targets  "
   echo " Examples - "
   echo " Default :  sh $0 n6001 AGFB014R24A2E2V  Agilex"
   echo " The device and family are, by default, parsed by the script from the qsf which"
   echo " are assumed to be in a pre-defined location. However, they can also be overridden"
   echo " by passing them as inputs to the script"
   exit -1
}

function remove_file {
   if [ -f $1 ] ; then
      rm -rf $1
   fi
}

# fpga/

if [ -z $1 ]; then
   echo "Error: No update target passed in to the script. "
   usage
fi

declare targets
if [ $1 = "all" ]; then
    targets=( "n6001"
	       "d5005" )
else
    targets=("$@")
fi
# SCRIPT_DIR=$OFS_ROOTDIR/scripts/common/sim
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
OFS_IP_SEARCH_PATH="$OFS_ROOTDIR/ofs-common/src/common/lib/**/*,$OFS_ROOTDIR/ipss/pmci/**/*,$OFS_ROOTDIR/src/pd_qsys/common/**/*,$"


for OFS_TARGET in ${targets[@]}
do

    # figure out the device and family.
    # Ideally, it can be figured out from the qsf. It can also be overridden by
    # a command line parameter
	case $OFS_TARGET in
		d5005)	QSF_FILE=$OFS_ROOTDIR/syn/syn_top/d5005.qsf;;
		*)       QSF_FILE=$OFS_ROOTDIR/syn/syn_top/ofs_top.qsf;;
	esac
    
    echo "QSF_FILE=$QSF_FILE"
    if [ -v 2 ]; then
        DEVICE=$2
        echo "DEVICE=$DEVICE"
    elif [ -f "$QSF_FILE" ]; then
        DEVICE=$(awk '/^set_global_assignment -name DEVICE / {print $4}' "$QSF_FILE")                                                                                                                                                      
        echo "DEVICE=$DEVICE"
    else
     echo "Error: No target device passed in to the script. "
     usage    
    fi
    
    if [ -v 3 ]; then
        FAMILY=$3
        echo "FAMILY=$FAMILY"
    elif [ -f "$QSF_FILE" ]; then
        FAMILY=$(awk '/^set_global_assignment -name FAMILY / {print $4}' "$QSF_FILE")                                                                                                                                                      
        echo "FAMILY=$FAMILY"
    else
     echo "Error: No target family passed in to the script. "
       usage    
    fi


    # Extracting IP Filelist path
    IP_FLIST="$OFS_ROOTDIR/syn/setup/ip_list.f"
    
    IP_FLIST_COMMON="$OFS_ROOTDIR/syn/common/setup/ip_list_common.f"
    SIM_SETUP_PREFIX="sim/scripts"
    SIM_SETUP_DIR="${OFS_ROOTDIR}/${SIM_SETUP_PREFIX}"
    

    # collect IPs into common list
    echo "OFS_TARGET = $OFS_TARGET"
    echo "IP_FLIST=$IP_FLIST"
    echo "IP_FLIST_COMMON=$IP_FLIST_COMMON"
    echo "SIM_SETUP_DIR=$SIM_SETUP_DIR"
    
    
    if [ -z $IP_FLIST ] || [ ! -f $IP_FLIST ]; then
    	echo "Error: IP flist \"$IP_FLIST\" does not exist."
    	usage
    fi
    
    if [ ! -d $SIM_SETUP_DIR ]; then
    	echo "Creating simulation setup directory for $OFS_TARGET"
    	mkdir -p $SIM_SETUP_DIR
    fi

    cat $IP_FLIST $IP_FLIST_COMMON > $SIM_SETUP_DIR/ip_flist_combined.f 


    # IP will be generated in $SIM_SETUP_DIR/qip_gen. Construct a tree
    # of links inside $SIM_SETUP_DIR/ip to the true IP files along
    # with a relocated IP ip_flist_reloc.f that points to the links.
    # This will cause all QSYS builds to be inside a single parent
    # directory instead of polluting the entire tree.

    rm -rf "${SIM_SETUP_DIR}"/qip_gen
    mkdir -p "${SIM_SETUP_DIR}"/qip_gen
    rm -f "$SIM_SETUP_DIR/ip_flist_reloc.f"
    touch "$SIM_SETUP_DIR/ip_flist_reloc.f"

    for ip in `grep -hvE '^(\s*$|#)' $SIM_SETUP_DIR/ip_flist_combined.f`
    do
        # Copy the IP build directory to the .qsys or .ip file's directory.
        # Copy the entire tree under the IP -- especially important
        # for .qsys files that may refer to IP below it.
        #
        # Ideally, we would just use links. This would generally work,
        # though in rare cases qsys writes through links and pollutes
        # the main directory.
        ip_dir=$(dirname "${ip}")
        mkdir -p "${SIM_SETUP_DIR}/qip_gen/${ip_dir}"
        rm -rf "${SIM_SETUP_DIR}/qip_gen/${ip_dir}"
        cp -r "$OFS_ROOTDIR/${ip_dir}" "${SIM_SETUP_DIR}/qip_gen/${ip_dir}"

        echo "${SIM_SETUP_PREFIX}/qip_gen/${ip}" >> "$SIM_SETUP_DIR/ip_flist_reloc.f"
    done

     
    echo "**** Generating HDL for $OFS_TARGET ****" 

    while read ip
    do
    	if [ -z "$batch_ip_list" ]; then
    	    batch_ip_list="$OFS_ROOTDIR/$ip"
    	else
    	    batch_ip_list="$batch_ip_list --batch=$OFS_ROOTDIR/$ip"
    	fi
    done < "$SIM_SETUP_DIR/ip_flist_reloc.f"

	echo "ofs_target = $OFS_TARGET"
    case $OFS_TARGET in
		d5005)	qsys-generate --simulation=VERILOG --simulator=VCS,VCSMX,MODELSIM --search-path="$OFS_IP_SEARCH_PATH" $batch_ip_list --family="Stratix 10" --part="$DEVICE";;
		*)      qsys-generate --simulation=VERILOG --simulator=VCS,VCSMX,MODELSIM --search-path="$OFS_IP_SEARCH_PATH" $batch_ip_list --family="$FAMILY" --part="$DEVICE";;
	esac
	
    if [ $? -ne 0 ]; then
    	echo "HDL generation failed. Check the errors for details."
    	exit -1
    fi

    echo "**** Done generating HDL for $OFS_TARGET ****" 


    echo "**** Generating simulation setup for $OFS_TARGET ****" 

    while read ip
    do
    	ip_dir=$(dirname -- $ip)
    	ip_file=$(basename -- $ip)
    	ip_name=$(echo $ip_file | sed -e "s/\..*$//g")

    	spd="${ip_dir}/${ip_name}/${ip_name}.spd"
    	spd_tmp="${ip_dir}/${ip_name}/${ip_name}_tmp.spd"
    	cp $OFS_ROOTDIR/$spd $OFS_ROOTDIR/$spd_tmp
    	sed '/\<device name=/d' -i $OFS_ROOTDIR/$spd_tmp

    	if [ -z "$spd_list" ]; then
    	    spd_list="$OFS_ROOTDIR/$spd_tmp"
    	else
    	    spd_list="${spd_list}, $OFS_ROOTDIR/$spd_tmp"
    	fi
    done < "$SIM_SETUP_DIR/ip_flist_reloc.f"

	case $OFS_TARGET in
		d5005)	ip-make-simscript --spd="${spd_list}" --use-relative-paths --output-directory="$SIM_SETUP_DIR/qip_sim_script" --device-family="Stratix 10";;
		*)		ip-make-simscript --spd="${spd_list}" --use-relative-paths --output-directory="$SIM_SETUP_DIR/qip_sim_script" --device-family="Agilex";;
	esac
    
    make_simscript_status=$?
    
    # Clean up files before checking status
    for ip in `grep -vE '^(\s*$|#)' $IP_FLIST`
    do
    	ip_dir=$(dirname -- $ip)
    	ip_file=$(basename -- $ip) 
    	ip_name=$(echo $ip_file | sed -e "s/\..*$//g") 
    	rm -rf $OFS_ROOTDIR/${ip_dir}/${ip_name}/${ip_name}_tmp.spd
    done

    if [ $make_simscript_status -ne 0 ]; then
    	echo "Simulation setup generation failed. Check the errors for details."
    	exit -1
    fi

    echo "**** Done generating simulation setup for $OFS_TARGET ****" 

    echo "**** Generating filelist for $OFS_TARGET ****" 

    if [ -f $SIM_SETUP_DIR/ip_flist.sh ]; then
       rm -rf $SIM_SETUP_DIR/ip_flist.sh
    fi


    python $SCRIPT_DIR/gen_sim_filelist.py --qsys_list="$SIM_SETUP_DIR/ip_flist_reloc.f" --output_file="$SIM_SETUP_DIR/ip_flist_new.sh"

    
    if [ $? -ne 0 ]; then
    	echo "Simulation filelist generation failed. Check the errors for details."
    	exit -1
    fi

    # Create MSIM list
    cp $SIM_SETUP_DIR/ip_flist_new.sh $SIM_SETUP_DIR/msim_ip_flist_new.sh
    sed -i 's/synopsys/mentor/' $SIM_SETUP_DIR/msim_ip_flist_new.sh

    mv $SIM_SETUP_DIR/ip_flist_new.sh $SIM_SETUP_DIR/ip_flist.sh	
    mv $SIM_SETUP_DIR/msim_ip_flist_new.sh $SIM_SETUP_DIR/msim_ip_flist.sh
    cp $SIM_SETUP_DIR/ip_flist_new.f $SIM_SETUP_DIR/msim_ip_flist.f
    sed -i 's/synopsys/mentor/' $SIM_SETUP_DIR/msim_ip_flist.f 
    mv $SIM_SETUP_DIR/ip_flist_new.f $SIM_SETUP_DIR/ip_flist.f
    echo "ip_flist = $SIM_SETUP_DIR/ip_flist.f"
    echo "Successfully generated simulation setup files"
    
    remove_file design_files.txt
    remove_file memory_files.txt
    remove_file *.hex
    remove_file *.mif

    echo "**** Done generating SIM filelist for $OFS_TARGET ****" 

done

