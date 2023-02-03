all: vuart_csr.sv vuart_csr_spec.html vuart_csr.xml

vuart_csr.sv: vuart_csrs.ini ../../../../tools/mk_csr_module/mk_cfg_module_64.pl vuart_csr_template.sv
	../../../../tools/mk_csr_module/mk_cfg_module_64.pl vuart_csrs.ini

vuart_csr_spec.html: vuart_csrs.ini ../../../../tools/mk_csr_module/mk_cfg_module_64.pl vuart_csr_template.sv
	../../../../tools/mk_csr_module/mk_cfg_module_64.pl vuart_csrs.ini

vuart_csr.xml: vuart_csrs.ini ../../../../tools/mk_csr_module/mk_cfg_module_64.pl vuart_csr_template.sv
	../../../../tools/mk_csr_module/mk_cfg_module_64.pl vuart_csrs.ini

clean:
	rm -f vuart_csr.sv vuart_csr_spec.html vuart_csr.xml
