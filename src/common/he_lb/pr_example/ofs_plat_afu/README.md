# Full PIM-based HE LB

This tree holds a wrapper around HE LB that can be used with PR and the PIM's ofs_plat_afu() top-level container. Instantiate it like any out-of-tree build using afu\_synth\_setup or afu\_sim\_setup.

If local memory is available, an instance of HE MEM is attached to host channel 0. If no local memory is available, HE LB is used instead. If a second host channel is available, an instance of HE LB is attached to host channel 1.