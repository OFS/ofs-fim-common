# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: MIT

all: example_csr.sv example_csr_spec.html example_csr.xml

example_csr.sv: example_csrs.ini mk_cfg_module_64.pl example_csr_template.sv
	mk_cfg_module_64.pl example_csrs.ini

example_csr_spec.html:example_csrs.ini mk_cfg_module_64.pl example_csr_template.sv
	mk_cfg_module_64.pl example_csrs.ini

example_csr.xml:example_csrs.ini mk_cfg_module_64.pl example_csr_template.sv
	mk_cfg_module_64.pl example_csrs.ini

clean:
	rm -f example_csr.sv example_csr_spec.html example_csr.xml
