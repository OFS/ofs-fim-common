# Copyright 2020 Intel Corporation
# SPDX-License-Identifier: MIT

'''
Script to generate FME ID MIF
'''

import os
import subprocess
import sys
import uuid
import datetime

try:
    from shlex import quote as shell_quote  # pylint: disable=E0611
except ImportError:
    from pipes import quote as shell_quote


def sha1_file_tree(base_path):
    '''
    Generate SHA1 hash for design source tree
    '''
    sha1sum = subprocess.check_output(
        ('find {base_path} -type f ! -name update_fme_ifc_id.py -print0 | '
         'sort -z | '
         'xargs -0 sha1sum | '
         'sha1sum'.format(base_path=shell_quote(base_path))),
        shell=True)
    return str(sha1sum).split()[0]


def write_fme_id_mif(platform_base_path, fme_id_list):
    '''
    Write FME ID MIF
    '''
#    path = 'design/corefim/fme/fme_id_rom/stratix10/pac_d5005/'
    path = ''
    path += 'fme_id.mif'
    with open(os.path.join(platform_base_path, path), 'r') as infile:
        old_mif = infile.readlines()

    path = os.path.join(platform_base_path, 'fme_id.mif')
    with open(path, 'w') as outfile:
        for entry in old_mif:
            if 'CONTENT' not in entry:
                outfile.write("%s" % entry)
            else:
                break

        outfile.write("CONTENT BEGIN\n")
        for index, value in enumerate(fme_id_list):
            outfile.write("	%s   :   %s;\n" % (format(index, '02x'),
                                               value))
        outfile.write("END;\n")


def generate_fme_id_mif(platform_base_path, project):
    '''
    Generate FME ID MIF
    '''

    reserved_64 = '0000000000000000'

    if 'BITSTREAM_ID' in os.environ:
        bitstream_id = os.environ.get('BITSTREAM_ID')
    else:
        print("\mError: BITSTREAM_ID variable not set!")
        sys.exit(-1)

    if 'BITSTREAM_MD' in os.environ:
        bitstream_md = os.environ.get('BITSTREAM_MD')
    else:
        print("\nError: BITSTREAM_MD variable not set!")
        sys.exit(-1)

    if 'BITSTREAM_INFO' in os.environ:
        bitstream_info = os.environ.get('BITSTREAM_INFO')
    else:
        print("\nError: BITSTREAM_INFO variable not set!")
        sys.exit(-1)

        
    #### REMOVING CHECKS as other platforms may have different register size
    #### checks done for size in previous state. 
    ## Checking to ensure bitstream_md and bitstream_id length are correct
    ## Just incase future edits violate format
    #if len(bitstream_id) != bitstream_info['bitstream_reg_length']:
    #    print("\nError: bitstream_id length does not equal to 16")
    #    sys.exit(-1)
    #if len(bitstream_md) != bitstream_info['bitstream_reg_length']:
    #    print("\nError: bitstream_md length does not equal to 16")
    #    sys.exit(-1)

    fme_afu_id = uuid.UUID('f9e17764-38f0-82fe-e346-524ae92aafbf')
    uuid_str = str(uuid.uuid5(fme_afu_id, sha1_file_tree(platform_base_path)))

    # Generate fme-ifc-id.txt for AFU compilation
    path = os.path.join(platform_base_path, 'fme-ifc-id.txt')
    with open(path, 'w') as outfile:
        outfile.write(uuid_str)

    # Generate FME ID MIF
    uuid_str = uuid_str.replace('-', '')
    fme_id_list = []
    fme_id_list.append(bitstream_id)
    fme_id_list.append(bitstream_md)
    fme_id_list.append(format(uuid_str[16:32]))
    fme_id_list.append(format(uuid_str[0:16]))
    fme_id_list.append(bitstream_info)
    fme_id_list.append(reserved_64)
    fme_id_list.append(reserved_64)
    fme_id_list.append(reserved_64)

    write_fme_id_mif(platform_base_path, fme_id_list)


# ----------------------------
#  Main Entry
# ----------------------------
if __name__ == '__main__':
    generate_fme_id_mif(sys.argv[1], sys.argv[2])
