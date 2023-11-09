# Out-of-Band TLP Headers

The normal PCIe SS stream encoding places TLP headers in-band with the data stream. The [ofs\_fim\_pcie\_hdr\_extract.sv](ofs_fim_pcie_hdr_extract.sv) module separates a standard PCIe Subsystem stream into two streams, one with headers and one with data. The header stream remains a pcie\_ss\_axis\_if, though the high bits of the bus beyond the header are zero. The data stream is realigned to begin at the first bit of the data bus in the data pcie\_ss\_axis\_if stream. Clients must manage the association between a header and a data packet.

The [ofs\_fim\_pcie\_hdr\_merge.sv](ofs_fim_pcie_hdr_merge.sv) module performs the reverse transformation, mapping separate header and data streams to a single stream with in-band headers.
