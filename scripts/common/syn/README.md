# OFS FPGA Image Build

## Overview

The syn directory contains Quartus projects and scripts to build the OFS designs within this repository.

## Usage

### Quartus compilation (FIM)

Before compiling an OFS FIM, a Quartus project must be generated. OFS provides a script that configures a project for a given board. The script defines three phases: setup, compilation and finish:

* *Setup* creates a Quartus project in a work directory.
* *Compile* invokes the standard Quartus flow, ending with the creation of SOF programming files that can be loaded over JTAG. Compilation with the OFS-provided script is equivalent to changing to the project's Quartus root directory and then running the Quartus flow in the GUI or with "quartus_sh --flow compile".
* *Finish* prepares programming files that can be written to flash. *Finish* may also generate a release for use with PR compilation and simulation, as described in [https://github.com/OFS/examples-afu/tree/main/tutorial](https://github.com/OFS/examples-afu/tree/main/tutorial).

#### Scripted FIM setup or compilation

1.	Get a "bash" shell (e.g. xterm).
2.  Set the tool paths for Quartus.
3.	Go to the OFS repository root directory. The root is the top-level directory in a platform-specific instance of OFS and will have this README file under ./ofs-common/scripts/common/syn.
4.	Set the required environment and directory structure variables:
```bash
        export OFS_ROOTDIR=<FIM root directory>
        export WORKDIR=<FIM root directory>
```
5. Run ./ofs-common/scripts/common/syn/build_top.sh \[--stage=\<action\>\] \[-p\] \<target\> \<work_dir\>
   * Arguments in brackets are optional. Remove the brackets when used.
   * *Action* must be one of *all, setup, compile and finish*. *All* runs all three stages. The three stages are described above. The compilation stage may be run multiple times without rerunning setup. The default action is *all*, which is equivalent to running *setup, compile* and *finish* in succession.
   * \<target\> is the platform \(n6001, d5005, etc.\).
   * \<work_dir\> is a path that can be inside or outside of the local repository, e.g.:
     * OFS N6001 project: ./ofs-common/scripts/common/syn/build_top.sh -p n6001 work_n6001
     * OFS D5005 project: ./ofs-common/scripts/common/syn/build_top.sh -p d5005 /tmp/work_d5005
   * If \<work_dir\> is omitted, the target default is (\<local repo\>/work).
   * Compiled reports and artifacts \(.rpt, .sof, etc.\) will be in \<work_dir\>/syn/syn_top/output_files.
   * A log file is created in OFS_ROOTDIR.
   * The "-p" argument is optional. When set, an out-of-tree PR release is created during *finish*. (See below.)

<br>
The n6001 FIM supports comma separated compile time options that could be handy for development. For example:

```bash
    ./ofs-common/scripts/common/syn/build_top.sh n6001:<option1>,<option2> work_n6001
````
* flat: Compiles a flat design (no PR assignments). Useful for bringing up the design on a new board without dealing with PR complexity.
* null_he_lb,null_he_hssi,null_he_mem,null_he_mem_tg: Replaces the target exercisers within the code with "he_null". Any combination, order or all can be enabled at the same time. "he_null" is a minimal block with CSRs that responds to PCIe MMIO requests. MMIO responses are required to keep PCIe alive.
* If an exerciser with other I/O connections such has "he_mem" or "he_hssi" is replaced, those I/O ports are simply tied off.
* Finer grain control is provided since the user may just turn off the exercisers in the static region only (not changing the PR region) to save area. Removing exercisers from the PR region during the base build is often a poor choice, since the exercisers aid with reasonable routing of signals that cross the PR boundary.
* Options apply only to the setup stage.

The compile stage checks for an environment variable named *SEED*. If present, the project\'s SEED is updated before the Quartus flow is started.

#### FIM compilation in the Quartus GUI

Once the FIM has been set up using the scripted flow, it is possible to build the configured project within the Quartus GUI. The GUI flow produces the same OFS timing report in \<work_dir\>/syn/syn_top/output_files/timing_report/ as the *compile* scripted flow. The GUI flow also generates the same .sof files in \<work_dir\>/syn/syn_top/output_files/. A developer adding Signal Tap to a FIM build and loading .sof files over JTAG with a programming cable could work successfully solely inside the GUI.

The GUI flow stops after the assembler and timing analyzer run. The scripts that update the PR environment and generate flash images are not invoked, leaving stale state. Consequently, the GUI could be used to define and debug a FIM, but the scripted flow will ultimately be required if more than a FIM .sof is required. Once a GUI compilation is done, the build_top.sh *finish* flow can be invoked to complete a full build.

#### Examples

The following command sequences are functionally equivalent.

Full flow:
```bash
    ./ofs-common/scripts/common/syn/build_top.sh -p n6001 work_n6001
```
Individual steps:
```bash
    ./ofs-common/scripts/common/syn/build_top.sh --stage setup n6001 work_n6001
    ./ofs-common/scripts/common/syn/build_top.sh --stage compile n6001 work_n6001
    ./ofs-common/scripts/common/syn/build_top.sh --stage finish -p n6001 work_n6001
```
Individual steps using the Quartus flow directly. The Quartus GUI can be used instead of quartus_sh:
```bash
    ./ofs-common/scripts/common/syn/build_top.sh --stage setup n6001 work_n6001
    # Project and revision names may be different on other boards
    (cd work_n6001/quartus_proj_dir/; quartus_sh --flow compile ofs_top -c ofs_top)
    ./ofs-common/scripts/common/syn/build_top.sh --stage finish -p n6001 work_n6001
```

#### PIM-based AFUs in the FIM compilation

In the FIM build, the standard AFUs in the port gasket can be replaced with PIM-based AFUs, wrapped by the ofs_plat_afu\(\) top-level module. Before invoking build_top.sh, set the environment variable AFU_WITH_PIM to the path of a sources text file -- the same sources file from examples such as [sources.txt in hello_world](https://github.com/OFS/examples-afu/blob/main/tutorial/afu_types/01_pim_ifc/hello_world/hw/rtl/axi/sources.txt):

```bash
    export AFU_WITH_PIM=<path to>/tutorial/afu_types/01_pim_ifc/hello_world/hw/rtl/axi/sources.txt
```

When set during the build_top.sh setup stage, the FIM build is configured to load the specified AFU. PR will continue to work, if enabled. The only difference with AFU_WITH_PIM is the change to the AFUs present at power-on. Keep in mind that the default exercisers were chosen to attach to all devices and force reasonable routing decisions during the FIM build across the PR boundary. AFU_WITH_PIM is best used for FIMs that disable PR.

Configuration of the user clock from an AFU's JSON file is ignored in a FIM build.

The AFU_WITH_PIM setting matters only during the setup stage of build_top.sh. It is not consumed by later stages.

### Quartus compilation (PR)

A full FIM compilation must be completed using build_top.sh before PR compilation is possible. PR compilations produce a GBS file, which is a wrapper around a Quartus-generated RBF file and a JSON metadata file. GBS files are read by the OPAE fpgasupdate, fpgaconf and packager tools. The JSON metadata includes the UUID of the FIM instance and settings for user clock frequency.

There are two mechanisms for working with PR projects: in-tree and out-of-tree (recommended).

#### In-tree PR flow

In-tree PR compilation uses the same project and environment as the base FIM build: \<work_dir\>/syn/syn_top/. PR compilation may either use OFS-provided scripts or be run from the Quartus GUI after selecting the PR revision. For the scripted flow, from the OFS root directory run:

```bash
    ./ofs-common/scripts/common/syn/compile_pr_slot.sh <target> <work_dir>
```

For example, ./ofs-common/scripts/common/syn/compile_pr_slot.sh d5005 work_d5005. The work directory must match the work directory that was created in the FIM compilation.

The compile_pr_slot.sh script does little more than invoke the usual Quartus flow and summarize the result. The Quartus GUI produces exactly the same GBS file and timing summary.

Most developers use PR because they are developing multiple accelerators that will be plugged into a common FIM build. For them, the out-of-tree flow is typically preferable.

#### Out-of-tree PR flow

The out-of-tree PR flow is based on a "release" tree generated at the end of a FIM build. Release trees are relocatable in the filesystem, contain only relative file paths, and may be used by PR developers without requiring the original FIM build tree for PR compilation. Release trees also support co-simulation with OPAE software workloads using [OPAE SIM \(ASE\)](https://github.com/OFS/opae-sim).

An out-of-tree release is created in \<work_dir\>/pr_build_template/ at the end of a FIM build when the -p switch is set during build_top.sh. Setting the -p switch is equivalent to running the following from the FIM root directory after a FIM build:

```bash
    ./ofs-common/scripts/common/syn/generate_pr_release.sh -t <work_dir>/pr_build_template <target> <work_dir>
````

There is no need to run generate_pr_release.sh if you have already passed -p to build_top.sh. A tutorial describing the mechanics of working with out-of-tree releases is available in [examples-afu](https://github.com/OFS/examples-afu/tree/main/tutorial). The release tree in pr_build_template is the OPAE_PLATFORM_ROOT tree expected by the tutorial.

Like the in-tree flow, PR compilation may either be driven by a script ($OPAE_PLATFORM_ROOT/bin/afu_synth) or by the standard flow in the Quartus GUI. Both produce a GBS file, compute the target user clock frequency and produce a timing report.

## Managing Platform Designer IP

OFS projects point to copies of IP and QSYS files, located in ../ip_lib/ relative to a project directory. This shadow copy avoids polluting git repositories with content generated from IP files such as simulation RTL. The copy is also required in order to keep the root directory of Quartus archives within the project subtree, due to the way Quartus maps IP sources to absolute paths.

IP is copied from the source tree to ../ip_lib/ during the setup stage of a build. When updating IP, users may need to copy IP back from ../ip_lib/ to the source tree. The emit_project_ip.tcl script handles both copies. See the description of [emit_project_ip.tcl](#emit_project_iptcl) below for instructions.

## Shell scripts

The following shell scripts are invoked during FIM or PR builds. In most cases, only build_top.sh is run by a user and the remainder are invoked internally.

### build_fim.sh <br> build_fim_setup.sh <br> build_fim_compile.sh <br> build_fim_finish.sh

The main FIM build scripts that implement the *all, setup, compile* and *finish* stages from build_top.sh.
* build_fim.sh runs setup, compile and finish in sequence.
* build_fim_setup.sh creates a Quartus project and applies any options, such as *no_hssi*.
* build_fim_compile.sh changes to the project\'s root directory and invokes the Quartus compile flow.
* build_fim_finish.sh creates flash images and an out-of-tree PR release.

### build_top.sh

The entry point to the FIM build flow, described in [Quartus compilation (FIM)](#quartus-compilation-fim) above.

The OFS build scripts get the pointer to a board-specific build_var_setup.sh from the first argument. The optional second argument is to specify the work directory.

* work directory can be a name \(creates work directory in ofs_dev directory)
* work directory can be a path \(path cannot be lower than ofs_dev/\<work\>, but can be in another location
* see create_work_dir.sh section below for more details and examples    

### build_var_setup_common.sh

Set up the build environment. The primary function is loading build variables from syn/\<OFS_PROJECT\>/scripts/build_var_setup.sh. build_var_setup_common.sh is a globally shared wrapper around project-specific build_var_setup.sh scripts. The project-specific build_var_setup.sh specifies project names, revisions, FME register values, build flow, script, etc.

When variable settings are project-independent, defining them in build_var_setup_common.sh avoids having to modify the same variable in every project-specific build_var_setup.sh. build_var_setup_common.sh can also be used to set a variable\'s default, leaving project-specific build_var_setup.sh only having to set the variable in unusual cases.

### compile_pr_slot.sh

Run an in-tree PR build. See [Quartus compilation (PR) - In-tree PR](#in-tree-pr-flow) flow above.

### create_work_dir.sh

Creates the work directory by either symlink or copy. The script can be run standalone \("create_work_dir.sh -h" for help\).

Work directory requirements:
* work directory needs to start with "work"  e.g. work_d5005 or work2 or /tmp/usr1/work_1
* can be specified by name or \<path\>/\<name\>
* if a name is specified, then the work directory will be created in ofs-dev/
* if a \<path\>/\<name\> is specified, then the directory path can be outside ofs-dev or in ofs-dev, but not in subdirectories lower than ofs-dev \(e.g. /tmp/work\)
* no argument will result in 'work' directory in ofs-dev: ofs_dev/work
* The work directory can be specified by a path \(work cannot lower directory than in ofs-dev\)
* correct usage: /tmp/gitlab_repos/ofs-dev/work1
* correct usage: /tmp/work1
* incorrect usage: /tmp/gitlab_repos/ofs-dev/syn/work1

Select copy files \(not symlink\):
* running as stand alone script: Can use -c inline argument 'create_work_dir.sh -c work1' or can set COPY_WORK variable: 'export COPY_WORK="1"' and then run 'create_work_dir.sh work1'
* running build_top.sh: set the COPY_WORK variable before running build_top.sh.  'export COPY_WORK="1"' then run build_top.sh

Forced overwrite work directory:
* running as a stand alone script: can use -f inline argument or set FORCE env variable: 'create_work_dir.sh -f' or 'export FORCE="1"'
* running build_top.sh: set FORCE varilable before running build_top.sh
* if the work directory exists and -f or FORCE is not set, then a prompt to continue \(no change\), force \(recopy or resymlink\), or exit. a timer will timeout and exit if nothing is entered before the timeout time.

### display_timing_pass_fail.sh

Displays whether timing passed or failed in the base FIM build.

This script checks the output file of report_timing.tcl to see if timing passes or fails and displays it. For use at the end of the build flow to indicate if timing is good nor not.

Displays OFS_PROJECT, OFS_FIM, OFS_BOARD, Fitter seed value, etc.

### generate_pr_release.sh

Creates an out-of-tree PR build template that is used for defining PR and simulator projects. See [Quartus Compilation (PR) - Out-of-tree PR flow](#out-of-tree-pr-flow) for details. generate_pr_release.sh may be run standalone or automatically at the end of a FIM build by passing "-p" to build_top.sh.

### pr_setup.sh

Creates an SDC file for PR compilation, extracting timing constraints from a FIM build into a single file that is loaded in PR projects. The script also emits a Tcl file that describes all the IP loaded during the FIM build to avoid having to duplicate the base IP configuration for PR by hand.

### setup_opae_sdk.sh

Clones [opae-sdk](https://github.com/OFS/opae-sdk) when it isn\'t already available in the build environment, builds PACSign and packager tools and adds opae-sdk/platforms/scripts to PATH.

The script can be run standalone to setup opae-sdk with default variables.

If parameters, such as repo address, branch, or target directories need to be changed, build_var_setup.sh contains commented out variables that can be uncommented and changed.

The script must be sourced as it sets environment variables.

## Quartus scripts

### config_env.tcl

OFS Quartus projects (.qsf files) run config_env.tcl to ensure that required environment variables are defined during a Quartus build. Variables are loaded from build_env_db.txt in a project\'s root directory. build_env_db.txt is populated by build_top.sh and other scripts that it invokes. Contents may have platform-dependent values, but always include BUILD_ROOT_REL (the path to the top of the work tree relative to the project directory) and FME_IFC_ID (the UUID of the FIM instance).

Quartus GUI builds are dependent on config_env.tcl to set environment variables that might otherwise be set by [OFS shell build scripts](#shell-scripts).

The side-effects of running config_env.tcl are not visible in the .qsf project script that invokes it, but side-effects are visible in Tcl scripts invoked from the main .qsf project. This is why OFS defines sources with paths relative to $::env(BUILD_ROOT_REL) in .tcl files, such as ofs_top_sources.tcl, and not in .qsf files.

### create_sdc_for_pr_compile.tcl

Creates SDC constraints using quartus_sta from FIM static region for use in PR compilation.

### emit_project_ip.tcl

emit_project_ip.tcl has several modes for managing the project-relative ../ip_lib/ tree. See [Managing Platform Designer IP](#managing-platform-designer-ip) above for more details.

* Mode *ip_lib* is invoked during the OFS build setup stage. It copies all IP and QSYS files defined in a project from the source tree to the ../ip_lib/ tree.
* Mode *tcl* is invoked within the OFS build script at the end of a FIM build. It generates a Tcl script for use by PR projects that loads all FIM IP. This way, PR projects do not have to maintain a duplicate copy of IP source lists.
* Mode *sync* is not invoked by the normal build flow. It copies a project\'s sources in the opposite direction of ip_lib. IP files that have been changed within the ../ip_lib/ tree are copied back to the git source tree.

Mode sync may be used to upgrade IP within a project:

Set up a build environment and run Quartus (using n6001 as an example):
```bash
./ofs-common/scripts/common/syn/build_top.sh --stage=setup n6001 work_n6001
cd work_n6001/syn/syn_top
quartus
```

Upgrade IP as needed, typically with Project->Upgrade IP Components. New IP may also be added to ../ip_lib/ and can be copied back to the git repository with mode sync. The compilation flow does not have to be run.

After exiting Quartus, still in the syn_top directory:

```bash
quartus_ipgenerate -t $OFS_ROOTDIR/ofs-common/scripts/common/syn/emit_project_ip.tcl --project=ofs_top --revision=ofs_top --mode=sync
```

Only files with a modification time newer than the target will be copied. emit_project_ip.tcl prints a message for each file copied. Verbose mode prints messages for files not copied. Run the script with --help for all arguments.

### emit_project_macros.tcl

emit_project_macros.tcl is run at the end of a FIM build while setting up a PR build environment. It discovers all macros defined in FIM .qsf and .tcl files and ensures that the same macros are present in downstream PR builds and in the OPAE SIM simulation environment.

### gen_gbs.tcl

gen_gbs.tcl is included in PR projects as a POST_FLOW_SCRIPT_FILE, which Quartus invokes at the end of the standard build flow. It wraps the assembled RBF file in a GBS container file using the OPAE SDK packager tool. GBS files can be loaded onto hardware by OPAE fpgasupdate.

### import_user_clk_sdc.tcl

This script is run during FIM builds, typically as a side-effect of timing constraints in the fitter. Given a pattern, it finds the full path of the user clock and emits a new Tcl script for use during PR builds to manage user clock timing constraints.

Most platforms define a platform-specific setup_user_clock_for_pr.sdc that invokes setup_user_clk_sdc, which is in import_user_clk_sdc.tcl. The output Tcl script is typically ofs_partial_reconfig/user_clock_defs.tcl.

### ofs_post_module_script_fim.tcl

This script is the platform-independent post-module script for FIM base builds. It should be loaded into all FIM projects, either as the POST_MODULE_SCRIPT_FILE or invoked from a platform-specific post-module script. The post-module script is invoked by Quartus after each stage in the compilation flow.

ofs_post_module_script_fim.tcl does the following:

* After quartus_fit:
  * Generates a new FIM unique ID
  * Writes the FIM ID to a memory file that will be embedded in the FPGA image by the assembler
* After quartus_sta:
  * Emits a summary SDC file with all timing constraints that can be loaded into PR projects
  * Emits a Tcl file that enumerates all IP used in the FIM build that can be loaded into PR projects
* After quartus_asm:
  * Exports the root partition database for use in PR projects

### ofs_sta_report_script_pr.tcl

This script is defined as TIMING_ANALYZER_REPORT_SCRIPT in OFS PR projects, causing it to be run automatically at the end of quartus_sta timing analysis. The script invokes two other .tcl scripts: user_clock_freqs_compute.tcl, which calculates the achieved Fmax of the user clock, and [report_timing.tcl](#report_timingtcl).

### report_timing.tcl

Generates clock timing reports in output_files/timing_reports. output_files/timing_reports/clocks.sta.failed.summary is used by other scripts to check if timing has passed or not \(empty file = timing pass\).

The timing report may be especially valuable when the user clock frequency is set automatically during a PR build, where the main quartus_sta timing report may indicate timing errors since it was run with the user clock set to an aggressive frequency. The timing report generated by report_timing.tcl reflects that true timing result, given the actual user clock frequency.

### update_fme_ifc_id.py

Edits FME memory contents (fme_id.mif) with the calculated PR ID and bitstream ID and metadata for the fme_id_rom IP file.

This script is used post syn and fit to edit the ROM contents after compilation, as the hash is a sha of the compile directory, to create a unique PR IP. Bitstream ID and MD are set and generated in the build_var_setup_common.sh. The script updates FME_IFC_ID in build_env_db.txt, causing it to be loaded into projects by [config_env.tcl](#config_envtcl). FME_IFC_ID is required by [gen_tbs.tcl](#gen_gbstcl).

### user_clock_freqs_compute.tcl

OFS projects can be configured to auto-compute the user clock frequency, setting it to the fMax achieved by the fitter. In this mode, the clock is artificially set to an aggressive target frequency in the fitter. During timing analysis, user_clock_freqs_compute.tcl walks the timing tables and sets the user clock\'s frequency to the achieved fMax. This script runs before report_timing.tcl so that the final timing summary reflects the chosen user clock frequency.

## Subdirectories

### build_flash

This directory contains the scripts necessary to build flash images for the associated OFS_PROJECT's board. Each project may be unique so separate build_flash content are part of the OFS project's scripts (this is not common). Please refer to the README file in the build_flash directory for more information.

### release_bin

The release_bin directory becomes $OPAE_PROJECT_ROOT/bin in PR releases and contains scripts for building and managing out-of-tree PR projects. See [release_bin/README](release_bin/README).
