#!/usr/bin/env python
# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

"""
    Generate simulation filelist for OFS FIM full chip simulation
    Only VCS is supported
"""

import os
import re
import sys
import argparse
import subprocess


class IPSimInfo:
    ''' IP simulation script info '''
    def __init__(self, ip_sim_path, ip_inst, sim_script):
        self.ip_sim_path = ip_sim_path
        self.ip_inst = ip_inst
        self.sim_script = sim_script

    def get_ip_sim_path(self):
        ''' Return ip_sim_path '''
        return self.ip_sim_path

    def get_ip_inst(self):
        ''' Return ip_inst '''
        return self.ip_inst

    def get_sim_script(self):
        ''' Return IP sim script '''
        return self.sim_script


def parse_arguments():
    '''
    Parse script arguments
    '''
    parser = argparse.ArgumentParser()

    parser.add_argument(
          "--qsys_list",
          required=True,
          default="ip_list.f",
          help="Path to qsys filelist"
    )

    parser.add_argument(
          "--src_file",
          required=False,
          default="",
          help="Source file")

    parser.add_argument(
          "--output_file",
          required=True,
          help="Output file")


    return parser.parse_args()


def get_sim_scripts(
    qsys_filelist,
    src_file,
    output_file
):
    print("gen_sim_filelist.py: Generate simulation script %s" % qsys_filelist)
    '''
    Generate simulation script
    '''
    gen_vcs_script(qsys_filelist, src_file, output_file)


def gen_vcs_script(
    qsys_filelist,
    src_file,
    output_file
):
    print("gen_sim_filelist.py: gen_vcs_script: Generate VCS simulation script")
    print("gen_sim_filelist.py: gen_vcs_script: qsys_filelist= %s" % qsys_filelist)
    print("gen_sim_filelist.py: gen_vcs_script: src_file=      %s" % src_file)
    print("gen_sim_filelist.py: gen_vcs_script: output_file=   %s" % output_file)
    '''
    Generate VCS simulation script
    '''
    rom_lines = {}
    ip_list = []
    file_lines = []

    # Iterate through the list of IP listed in qsys_filelist
    # and collect the filelist for each IP
    flist = open(qsys_filelist)
    for line in flist:
        line = line.strip()
        print("gen_sim_filelist.py: gen_vcs_script: line=%s" % line)
        if re.match(re.compile('^\s*#|^\s*$'), line):
            continue
        (head, tail) = os.path.split(line)
        (qsys, ext) = tail.split(".")

        if (ext == 'qsys' or ext == 'ip'):
            rel_sim_path = head + "/" + qsys + "/sim"
            full_sim_path = os.environ['OFS_ROOTDIR'] + "/" + rel_sim_path
            print("gen_sim_filelist.py: gen_vcs_script: full_sim_path=%s" % full_sim_path)
            print("gen_sim_filelist.py: gen_vcs_script: rel_sim_path=%s" % rel_sim_path)

            vcs_script = full_sim_path + "/common/vcs_files.tcl"

            sim_info = IPSimInfo(
                rel_sim_path,
                qsys,
                vcs_script
            )

            if os.path.exists(vcs_script):
                print("gen_sim_filelist.py: gen_vcs_script: Reading file list of %s" % qsys)
                gen_vcs_filelist(
                      sim_info,
                      rom_lines,
                      ip_list,
                      file_lines
                )
            else:
                print("gen_sim_filelist.py: gen_vcs_script: in else Reading file list of %s "
                      "(IP generated from older version of Quartus)" % qsys)

                vcs_script = full_sim_path + "/synopsys/vcs/vcs_setup.sh"

                sim_info = IPSimInfo(
                    rel_sim_path,
                    "NULL",
                    vcs_script
                )

                gen_old_ip_vcs_filelist(
                      sim_info,
                      rom_lines,
                      ip_list,
                      file_lines
                )
        else:
            print("Warning : exlude non qsys file : %s" % line)
    flist.close()

    write_vcs_script (
        src_file,
        output_file,
        rom_lines,
        file_lines
    )


def gen_vcs_filelist(
    sim_info,
    rom_lines,
    ip_list,
    file_lines
):
    '''
    Collect the simulation filelist given the IP instance name
    and the path to the IP VCS simulation script
    '''

    script_path = os.path.dirname(os.path.realpath(__file__))
    qsys_sim_path = "$OFS_ROOTDIR" + "/" + sim_info.get_ip_sim_path()

    try:
        subprocess.check_output(
            'tclsh %s/get_vcs_files.tcl %s %s'
            % (script_path, sim_info.get_ip_inst(), sim_info.get_sim_script()),
            shell=True)
    except subprocess.CalledProcessError as grepexc:
        print ("Error: tclsh get_vcs_files.tcl FAILED with error : ",
               grepexc.returncode,
               grepexc.output)
        sys.exit(1)

    mem_flist = open("memory_files.txt", 'r')
    for line in mem_flist:
        line = line.strip()
        if "QSYS_SIMDIR" in line:
            if "+incdir+" in line:
                rom_file = line
                if rom_file not in rom_lines:
                  rom_file = rom_file.replace("$QSYS_SIMDIR", qsys_sim_path)
                  rom_lines[rom_file] = "cp -f %s ./" % rom_file
                line = line.split()[1]
            rom_file = line
            if rom_file not in rom_lines:
                rom_file = rom_file.replace("$QSYS_SIMDIR", qsys_sim_path)
                rom_lines[rom_file] = "cp -f %s ./" % rom_file
    mem_flist.close()

    design_flist = open("design_files.txt", 'r')
    for line in design_flist:
        line = line.strip()
        if "QSYS_SIMDIR" in line:
            if "+incdir+" in line:
                ip_file = os.path.basename(line.split()[0])
                if ip_file not in ip_list:
                  line = line.replace("$QSYS_SIMDIR", qsys_sim_path)
                  line = line.replace('"', "")
                  line_inc = line.split()[0]
                  file_lines.append("%s" % line_inc)
                  ip_list.append(ip_file)
                line = line.split()[1]
            ip_file = os.path.basename(line.split()[0])
            if ip_file not in ip_list:
                line = line.replace("$QSYS_SIMDIR", qsys_sim_path)
                file_lines.append("%s" % line)
                ip_list.append(ip_file)
    design_flist.close()


def gen_old_ip_vcs_filelist(
    sim_info,
    rom_lines,
    ip_list,
    file_lines
):
    '''
    print("gen_sim_filelist.py: gen_old_ip_vcs_filelist: sim_info=  %s" % sim_info)
    print("gen_sim_filelist.py: gen_old_ip_vcs_filelist: rom_lines= %s" % rom_lines)
    print("gen_sim_filelist.py: gen_old_ip_vcs_filelist: ip_list=   %s" % ip_list)
    print("gen_sim_filelist.py: gen_old_ip_vcs_filelist: file_lines=%s" % file_lines)

    Collect the simulation filelist given the IP instance name
    and the path to the IP VCS simulation script

    This function is similar to gen_vcs_filelist
    except that it is catered for older version of QSYS IP
    '''

    qsys_sim_path = "$OFS_ROOTDIR" + "/" + sim_info.get_ip_sim_path()

    vcs_f = open(sim_info.get_sim_script(), 'r')

    s_copy_rom = False
    s_sim_files = False

    for line in vcs_f:
        line = line.strip()
        if s_copy_rom:
            if "fi" in line:
                s_copy_rom = False
            elif "vcs -lca" in line:
                s_copy_rom = False
                s_sim_files = True
            elif "QSYS_SIMDIR" in line:
                if "+incdir+" in line:
                    rom_file = os.path.basename(line.split()[-2])
                    if rom_file not in rom_lines:
                       line = line.replace("$QSYS_SIMDIR", qsys_sim_path)
                       rom_lines[rom_file] = line
                    line = line.split()[1]
                rom_file = os.path.basename(line.split()[-2])
                if rom_file not in rom_lines:
                    line = line.replace("$QSYS_SIMDIR", qsys_sim_path)
                    rom_lines[rom_file] = line
        elif s_sim_files:
            if "-top" in line:
                s_sim_files = False
            elif "QSYS_SIMDIR" in line:
                if "+incdir+" in line:
                    ip_file = os.path.basename(line.split()[0])
                    if ip_file not in ip_list:
                       line = line.replace("$QSYS_SIMDIR", qsys_sim_path)
                       line = line.replace('"', "")
                       line_inc = line.split()[0]
                       file_lines.append(line_inc)
                       ip_list.append(ip_file)
                    line = line.split()[1]
                ip_file = os.path.basename(line.split()[0])
                if ip_file not in ip_list:
                    line = line.replace("$QSYS_SIMDIR", qsys_sim_path)
                    file_lines.append(line)
                    ip_list.append(ip_file)
        else:
            if ("copy ram/rom" in line.lower() or
                    "copy rom/ram" in line.lower()):
                s_copy_rom = True
            elif "vcs -lca" in line:
                s_sim_files = True
    vcs_f.close()


def write_vcs_script(
    infile,
    outfile,
    rom_lines,
    file_lines
):
    '''
    Write VCS script
    '''
   
    output_dir=os.path.dirname(outfile)
    filename=os.path.splitext(os.path.basename(outfile))[0]

    ip_flist=output_dir+"/"+filename+".f"

    fout = open(outfile, 'w')
    
    if not infile:
        has_template = False
        
        # IP memory initialization files
        write_rom_lines(fout, has_template, "", rom_lines, False)

        # IP files
        write_vcs_ip(fout, has_template, "", file_lines, False)
    else:
        # Read in existing ip_flist_new.sh
        # Copy the content from existing ip_flist_new.sh
        # to new ip_flist_new.sh, except for IP filelist
        # which is generated from the filelist retrieved earlier from each IP
        has_template = True
        skip_line = False

        fin = open(infile, 'r')
        for line in fin:
            line = line.strip()

            # IP memory initialization files
            skip_line = write_rom_lines(fout, has_template, line, rom_lines, skip_line)

            # IP files
            skip_line = write_vcs_ip(fout, has_template, line, file_lines, skip_line)

            if not skip_line:
                fout.write("%s\n" % line)
        fin.close()

    fout.close()
    
    # Generate IP filelist
    fout = open(ip_flist, 'w')
    write_ip_flist(fout, file_lines)
    fout.close()


def write_rom_lines(fout, has_template, line, rom_lines, cur_skip_line):
    '''
    If line is start of ROM section,
    write IP memory initialization files to sim script
    '''
    skip_line = cur_skip_line

    if has_template:
        if "COPY_IP_ROM_BEGIN" in line:
            skip_line = True
            fout.write("%s\n" % line)
            for key in rom_lines:
                fout.write("%s\n" % rom_lines[key])
        elif "COPY_IP_ROM_END" in line:
            skip_line = False
    else:
        for key in rom_lines:
            fout.write("%s\n" % rom_lines[key])

    return skip_line


def write_vcs_ip(fout, has_template, line, ip_lines, cur_skip_line):
    '''
    If line is start of IP filelist section,
    write IP filelist to VCS script
    '''
    skip_line = cur_skip_line

    if has_template:
        if "QSYS_FILELIST_BEGIN" in line:
            skip_line = True
            fout.write("%s\n" % line)
            fout.write("QSYS_FILELIST=\"")
            for ip_line in ip_lines:
                fout.write("%s \\\n" % ip_line)
            fout.write("\"\n")
        elif "QSYS_FILELIST_END" in line:
            skip_line = False
    else:
        fout.write("QSYS_FILELIST=\"")
        for ip_line in ip_lines:
            fout.write("%s \\\n" % ip_line)
        fout.write("\"\n")
    return skip_line

def write_ip_flist(fout, ip_lines):
    '''
    write IP filelist
    '''
    for ip_line in ip_lines:
        fout.write("%s\n" % ip_line)


def gen_msim_script(
    qsys_filelist,
    src_file,
    output_file
):
    '''
    Generate Modelsim simulation script
    '''
    rom_lines = {}
    ip_list = []
    file_lines = []

    qsys_f = open(qsys_filelist)
    for line in qsys_f:
        line = line.strip()
        if re.match(re.compile('^#|^\s*$'), line):
            continue
        (head, tail) = os.path.split(line)
        (qsys, ext) = tail.split(".")

        if (ext == 'qsys' or ext == 'ip'):
            rel_sim_path = head + "/" + qsys + "/sim"
            full_sim_path = os.environ['OFS_ROOTDIR'] + "/" + rel_sim_path
            msim_script = full_sim_path + "/common/modelsim_files.tcl"

            sim_info = IPSimInfo(rel_sim_path, qsys, msim_script)

            if os.path.exists(msim_script):
                print("gen_sim_filelist.py: gen_msim_script: Reading file list of %s" % qsys)
                gen_msim_filelist(
                    sim_info,
                    rom_lines,
                    ip_list,
                    file_lines
                )
            else:
                print("gen_sim_filelist.py: gen_msim_script: in else Reading file list of %s "
                      "(IP generated from older version of Quartus)" % qsys)

                msim_script = full_sim_path + "/mentor/msim_setup.tcl"
                sim_info = IPSimInfo(rel_sim_path, "NULL", msim_script)

                gen_old_ip_msim_filelist(
                      sim_info,
                      rom_lines,
                      ip_list,
                      file_lines
                )
        else:
            print("Warning : exluce non qsys file : %s" % line)
    qsys_f.close()

    write_msim_script(
        src_file,
        output_file,
        rom_lines,
        file_lines
    )


def write_msim_script(
    infile,
    outfile,
    rom_lines,
    file_lines
):
    '''
    Write Modelsim script
    '''
    # Libraries
    lib_list = []
    for line in file_lines:
        if "-work" in line:
            lib = line.split()[-1]
            if lib not in lib_list:
                lib_list.append(lib)

    dev_lib_list = []
    fin = open(infile, 'r')

    get_msim_dev_lib(infile, dev_lib_list)

    skip_line = False
    fin = open(infile, 'r')
    fout = open(outfile, 'w')
    for line in fin:
        line = line.strip()

        # IP memory initialization files
        skip_line = write_rom_lines(fout, line, rom_lines, skip_line)

        # Library mapping
        skip_line = write_msim_lib(fout, line, lib_list, skip_line)

        # IP files
        skip_line = write_msim_ip(fout, line, file_lines, skip_line)

        if "eval vsim" in line:
            fout.write("%s\n" % gen_vsim_cmd(line, dev_lib_list, lib_list))
        elif not skip_line:
            fout.write("%s\n" % line)

    fin.close()
    fout.close()


def write_msim_lib(fout, line, lib_list, cur_skip_line):
    '''
    If line is start of MSIM lib section,
    write MSIM library to MSIM script
    '''
    skip_line = cur_skip_line

    if "MAP_LIBRARY_BEGIN" in line:
        skip_line = True
        fout.write("%s\n" % line)
        for lib in lib_list:
            fout.write("ensure_lib\t\t./libraries/%s\n" % lib)
            fout.write("vmap\t\t%s\t\t./libraries/%s/\n" % (lib, lib))
    elif "MAP_LIBRARY_END" in line:
        skip_line = False
        fout.write("%s\n" % line)

    return skip_line


def write_msim_ip(fout, line, ip_lines, cur_skip_line):
    '''
    If line is start of IP filelist section,
    write IP filelist to MSIM script
    '''
    skip_line = cur_skip_line

    if "QSYS_FILELIST_BEGIN" in line:
        skip_line = True
        fout.write("%s\n" % line)
        for ip_line in ip_lines:
            fout.write("%s\n" % ip_line)
    elif "QSYS_FILELIST_END" in line:
        skip_line = False
        fout.write("%s\n" % line)

    return skip_line


def get_msim_dev_lib(
    infile,
    dev_lib_list
):
    '''
       Retrieve dev library from infile
    '''

    proc_close_brace_re = re.compile("\}\s*$")
    s_dev_lib = False
    s_dev_com = False

    fin = open(infile, 'r')

    for line in fin:
        line = line.strip()
        if "proc ensure_lib" in line:
            s_dev_lib = True
        elif "alias dev_com {" in line:
            s_dev_com = True
        elif re.match(proc_close_brace_re, line):
            if s_dev_lib:
                s_dev_lib = False
            elif s_dev_com:
                s_dev_com = False
        elif s_dev_lib:
            if "vmap" in line:
                lib = line.split()[1].strip()
                dev_lib_list.append(lib)
        elif s_dev_com:
            if "-work" in line:
                lib = line.split("-work")[-1].strip()
                if lib not in dev_lib_list:
                    dev_lib_list.append(lib)
    fin.close()


def gen_vsim_cmd(
    line,
    dev_lib_list,
    lib_list
):
    '''
    Generate vsim command in the simulation script
    '''
    line = line.strip()
    line_split = line.split("-L")
    vsim_cmd = line_split[0]
    vsim_end = line_split[-1].split()[-1]

    for lib in dev_lib_list:
        vsim_cmd = vsim_cmd + " -L " + lib

    for lib in lib_list:
        vsim_cmd = vsim_cmd + " -L " + lib

    vsim_cmd = vsim_cmd + " " + vsim_end
    return vsim_cmd


def gen_msim_filelist(
    sim_info,
    rom_lines,
    ip_list,
    file_lines
):
    '''
    Collect the simulation filelist given the IP instance name
    and the path to the IP Modelsim simulation script
    '''

    script_path = os.path.dirname(os.path.realpath(__file__))
    
    qsys_sim_path = "$OFS_ROOTDIR" + "/" + sim_info.get_ip_sim_path()
    ip_file_re = re.compile("\"\$QSYS_SIMDIR\S*\"")

    try:
        subprocess.check_output(
              'tclsh %s/get_msim_files.tcl %s %s'
              % (script_path, sim_info.get_ip_inst(), sim_info.get_sim_script()),
              shell=True
        )
    except subprocess.CalledProcessError as grepexc:
        print ("Error: tclsh get_msim_files.tcl FAILED with error : ",
               grepexc.returncode,
               grepexc.output)
        sys.exit(1)

    mem_flist = open("memory_files.txt", 'r')
    for line in mem_flist:
        line = line.strip()
        if "QSYS_SIMDIR" in line:
            if "+incdir+" in line:
                line = line.split()[1]
            rom_file = line
            if rom_file not in rom_lines:
                rom_file = rom_file.replace("$QSYS_SIMDIR", qsys_sim_path)
                rom_lines[rom_file] = "file copy -force %s ./" % rom_file
    mem_flist.close()

    design_flist = open("design_files.txt", 'r')
    for line in design_flist:
        line = line.strip()
        if "QSYS_SIMDIR" in line:
            if "+incdir+" in line:
                line = line.split()[1]
            ip_file = ip_file_re.findall(line)[0]
            lib = line.split()[-1]
            ip_sub_re = re.compile(lib + '/' + '\S*')
            if (lib + '/') in ip_file:
                ip_file = ip_sub_re.findall(ip_file)[0]
            else:
                ip_file = os.path.basename(ip_file)
            if ip_file not in ip_list:
                line = line.replace("$QSYS_SIMDIR", qsys_sim_path)
                line = "eval %s" % line
                file_lines.append(line)
                ip_list.append(ip_file)
    design_flist.close()


def gen_old_ip_msim_filelist(
    sim_info,
    rom_lines,
    ip_list,
    file_lines
):
    '''Collect the simulation filelist given the IP instance name
    and the path to the IP Modelsim simulation script

    This function is similar to gen_msim_filelist
    except that it is catered for older version of QSYS IP
    '''

    qsys_sim_path = "$OFS_ROOTDIR" + "/" + sim_info.get_ip_sim_path()

    msim_f = open(sim_info.get_sim_script(), 'r')

    s_copy_rom = False
    s_sim_files = False

    for line in msim_f:
        line = line.strip()

        if s_copy_rom:
            s_copy_rom = get_old_msim_rom_line(line, rom_lines, qsys_sim_path)
        elif s_sim_files:
            s_sim_files = get_old_msim_ip_line(
                  line, file_lines, ip_list, qsys_sim_path)
        else:
            if ("copy ram/rom" in line.lower() or
                    "copy rom/ram" in line.lower()):
                s_copy_rom = True
            elif "alias com {" in line:
                s_sim_files = True

    msim_f.close()


def get_old_msim_rom_line(line, rom_lines, qsys_sim_path):
    ''' Extract memory init file from line '''
    copy_rom = True

    if "}" in line:
        copy_rom = False
    elif "file copy" in line:
        rom_file = os.path.basename(line.split()[-2])
        if rom_file not in rom_lines:
            line = line.replace("$QSYS_SIMDIR", qsys_sim_path)
            rom_lines[rom_file] = line

    return copy_rom


def get_old_msim_ip_line(line, ip_lines, ip_list, qsys_sim_path):
    ''' Extract IP file from line '''

    sim_files = True
    ip_file_re = re.compile("\"\$QSYS_SIMDIR\S*\"")
    proc_close_brace_re = re.compile("\}\s*$")

    if "QSYS_SIMDIR" in line:
        if "+incdir+" in line:
            line = line.split()[1]
        ip_file = ip_file_re.findall(line)[0]
        lib = line.split()[-1]
        ip_sub_re = re.compile(lib + '/' + '\S*')

        if (lib + '/') in ip_file:
            ip_file = ip_sub_re.findall(ip_file)[0]
        else:
            ip_file = os.path.basename(ip_file)

        if ip_file not in ip_list:
            line = line.replace("$QSYS_SIMDIR", qsys_sim_path)
            ip_lines.append(line)
            ip_list.append(ip_file)
    elif re.match(proc_close_brace_re, line):
        sim_files = False

    return sim_files


def main():
    ''' Main entry '''
    args = parse_arguments()
    get_sim_scripts(args.qsys_list, args.src_file, args.output_file)


# Main Entry
if (__name__ == "__main__"):
    main()

