# VXI11 - Instrument Network Interface

[![Build Status](https://travis-ci.org/Keno/VXI11.jl.svg?branch=master)](https://travis-ci.org/Keno/ONCRPC.jl)

VXI-11 is a specification for addressing networked test and measurement equipment.
The specification is [available](http://www.vxibus.org/specifications.html) on the VxiBus website.

The specification builds on the [ONC RPC](https://tools.ietf.org/html/rfc1831.html) protocol, of which
this package contains a simplified implementation.

# Usage
In this example, I'll be connecting to a Tektronix TDS2000 oscilloscope.
However, you may prefer using a higher level package such as Instruments.jl instead
of this package.
```
julia> using VXI11

julia> l = VXI11.Link(ip"192.168.1.199", 961)

julia> write(l, "*IDN?")
5

julia> String(read(l))
"TEKTRONIX,TBS2104,C020205,CF:91.1CT FV:v1.23; FPGA:v1.21; \n"
```