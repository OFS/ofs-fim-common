# Copyright 2022 Intel Corporation
# SPDX-License-Identifier: MIT
#
all: protocol_checker_csr.sv protocol_checker_csr_spec.html protocol_checker_csr.xml

protocol_checker_csr.sv: protocol_checker_csrs.ini ../../../tools/mk_csr_module/mk_cfg_module_64.pl protocol_checker_csr_template.sv
	../../../tools/mk_csr_module/mk_cfg_module_64.pl protocol_checker_csrs.ini

protocol_checker_csr_spec.html: protocol_checker_csrs.ini ../../../tools/mk_csr_module/mk_cfg_module_64.pl protocol_checker_csr_template.sv
	../../../tools/mk_csr_module/mk_cfg_module_64.pl protocol_checker_csrs.ini

protocol_checker_csr.xml: protocol_checker_csrs.ini ../../../tools/mk_csr_module/mk_cfg_module_64.pl protocol_checker_csr_template.sv
	../../../tools/mk_csr_module/mk_cfg_module_64.pl protocol_checker_csrs.ini

clean:
	rm -f protocol_checker_csr.sv protocol_checker_csr_spec.html protocol_checker_csr.xml
