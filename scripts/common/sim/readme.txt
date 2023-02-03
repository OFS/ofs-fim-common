Initial Setup:
1)	Get a "bash" shell (e.g. xterm)
2)	Go to the OFS Repo root directory.
3)  Set all tool paths vcs, python etc. Please make sure Tool versions used are as follows:
    VCS : vcsmx/Q-2020.03-SP2
    Python : python/3.7.7
    Quartus : 21.4
    #Not needed for unit test# SNPS VIP Portfolio Version : vip_Q-2020.03A
    #Not needed for unit test# PCIe VIP : Q-2020.03
    #Not needed for unit test# AXI VIP : Q-2020.03
    #Not needed for unit test# Ethernet VIP : Q-2020.03
4)	Set the required environment and directory Structure variables (as shown below)
    export OFS_ROOTDIR=<pwd>
    export WORKDIR=$OFS_ROOTDIR
    export QUARTUS_HOME=<Quartus Installation path upto /quartus>
    export QUARTUS_INSTALL_DIR=$QUARTUS_HOME
    export IMPORT_IP_ROOTDIR=$QUARTUS_HOME/../ip
    #Not needed for unit test# export VERDIR=$OFS_ROOTDIR/verification/n6000/base
    #Not needed for unit test# export VIPDIR=$VERDIR
    #Not needed for unit test# export DESIGNWARE_HOME=<VIP installation path>
5) Generate the sim files. 
   The sim files are not checked in and are generated on the fly. In order to do this, run the following steps
    a. Got to $OFS_ROOTDIR/ofs-common/scripts/common/sim
    b  Run the script "sh gen_sim_files.sh <target>" for e.g. "sh gen_sim_files.sh d5005" for the D5005 FIM.


5) **Running Test******
    Unit tests are placed under $OFS_ROOTDIR/sim/unit_test/<test_name>, for example, "$OFS_ROOTDIR/sim/unit_test/fme_csr_directed" for the FME CSR Directed Unit Test.
    Under each test, go to $OFS_ROOTDIR/sim/unit_test/<test_name>/scripts, for example: $OFS_ROOTDIR/sim/unit_test/fme_csr_directed/scripts 
    To run the simulation under each test:
        VCS  : sh run_sim.sh
        VCSMX: sh run_sim.sh VCSMX=1
        QuestaSim: sh run_sim.sh MSIM=1
    Please refer readme under respective testcase for more info.
