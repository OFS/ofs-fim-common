# PIM Sideband (other) Extension

The PIM provides a generic wrapper for adding new classes to the top-level interface. "Other" is an instance of that wrapper. 

## Purpose

Some platforms may have ports flowing into afu\_main\(\) that are not universal and apply only to a specific configuration. The mechanism defined here allows for extension of the PIM interface without having to modify the core PIM sources. You might choose to use this method for cases such as:

- Nonstandard clock or reset.
- Power or temperature control signals.
- Sideband flow control that does not fit into a normal AXI-S protocol, such as HSSI XON/XOFF.

## Mechanism

The "other" type is added to the PIM by adding the following to a platform's PIM .ini file:

```ini
[other]
;; Generic wrapper around a vector of ports
template_class=generic_templates
native_class=ports
num_ports=1
;; Type of the interface (provided by import)
type=ofs_plat_fim_other_if
import=<relative path from .ini file to this extend_pim directory>
```

This is the default configuration of sample FIMs.

The generic wrapper class is predefined in the base PIM sources and it instantiates the type specified in the .ini file. The type may be modified as needed without requiring any changes to the PIM. It will be added to the PIM's top-level plat_ifc as:

```SystemVerilog
plat_ifc.other.ports[0]
```

The vector of ports is used because all PIM interfaces are vectors.

A tie-off module must also be provided and is here: [ofs\_plat\_other\_fiu\_if\_tie\_off.sv](ofs_plat_other_fiu_if_tie_off.sv). The name must match the added class. The PIM instantiates the tie-off automatically unless it is explicitly disabled with the usual mechanism of setting the "OTHER\_IN\_USE\_MASK" to 1 in ofs\_plat\_if\_tie\_off\_unused. Once again, the "OTHER\_" prefix is due to the class name.

## Variations

The class here gets the name "other" solely because of the \[other\] section in the .ini file. The generic templates work with any section name. A FIM may add a new class by adding another section to the .ini file that uses the generic templates. There may be multiple sections using generic templates.
