module VXI11

include("ONCRPC.jl")
using .ONCRPC
include("rpc.jl")

const LOCK_TIMEOUT = 10000
const IO_TIMEOUT = 10000

mutable struct Link
    c::ONCRPC.Channel
    lid::UInt32
    maxRecvSize::UInt32
end

close(l::Link) = destroy_link(l.c, l.lid)

function Link(c::ONCRPC.Channel, device="inst0")
    link = create_link(c, Create_LinkParms(rand(Int32), false, 10000, device))
    @assert link.error == 0
    l = Link(c, link.link, link.maxRecvSize)
    finalizer(l, close)
    l
end

function Link(ip::Base.IPAddr, port, device="inst0")
    Link(ONCRPC.Channel(connect(ip, port)), device)
end

function Base.write(l::Link, data)
    buf = IOBuffer()
    write(buf, data)
    data = take!(buf)
    resp = device_write(l.c, Device_WriteParms(l.lid, UInt32(IO_TIMEOUT), UInt32(LOCK_TIMEOUT),
        UInt32(1) << 3, data))
    @assert resp.error == 0
    @assert resp.size == sizeof(data)
    sizeof(data)
end

function Base.read(l::Link)
    rr = device_read(l.c, Device_ReadParms(l.lid, UInt32(l.maxRecvSize), UInt32(IO_TIMEOUT), UInt32(LOCK_TIMEOUT), UInt32(0), UInt32(0)))
    rr.data
end

end