# [Platform Interface Manager \(PIM\)](https://github.com/OPAE/ofs-platform-afu-bbb) version of afu\_main\(\)

afu\_main\(\) is the standard module in which AFU-specific logic begins.
The implementation here constructs the PIM's standard interface and then
instantiates the standard PIM ofs\_plat\_afu\(\) top-level AFU-specific module.

The std\_exerciser directory holds a version of the default exercisers,
implemented as a PIM-based AFU. It can be used as a default workload when
building a PR-based FIM.
