module ONCRPC

using Sockets: TCPSocket

export make_rpc

@enum msg_type CALL=0 REPLY=1
@enum reply_stat MSG_ACCEPTED=0 MSG_REKECTED=1
@enum accept_stat SUCCESS=0 PROG_UNAVAIL=1 PROG_MISMATCH=2 PROC_UNAVAIL=3 GARBAGE_ARGS=4 SYSTEM_ERR=5
@enum reject_stat RPC_MISMATCH=0 AUTH_ERROR=1
@enum auth_stat AUTH_OK=0 AUTH_BADCRED=1 AUTH_REJECTEDCRED=2 AUTH_BADVERF=3 AUTH_REJECTEDVERF=4 AUTH_TOOWEAK=5 AUTH_INVALIDRESP=6 AUTH_FAILED=7
@enum auth_flavor AUTH_NONE=0 AUTH_SYS=1 AUTH_SHORT=2
struct Channel{T<:IO}
    io::T
end

function read_reply(c::Channel{TCPSocket})
    reply_buf = IOBuffer()
    while true
        fragment_header = ntoh(read(c.io, UInt32))
        is_last = (fragment_header & (UInt32(1) << 31)) != 0
        length = fragment_header & ~(UInt32(1) << 31)
        write(reply_buf, read(c.io, length))
        if is_last
            break
        end
    end
    seekstart(reply_buf)
end

const max_fragment_size = ~(UInt32(1) << 31)
function frame_and_send(c::Channel{TCPSocket}, data)
    data = take!(data)
    length = sizeof(data)
    offset = 1
    while length > max_fragment_size
        write(c.io, max_fragment_size)
        write(c.io, data[offset:(offset+max_fragment_size-1)])
        length -= max_fragment_size
    end
    buf = IOBuffer()
    framing_length = UInt32(length-offset+1) | (UInt32(1) << 31)
    write(buf, hton(framing_length))
    write(buf, data[offset:end])
    write(c.io, take!(buf))
end

function make_call(c::Channel, prog::UInt32, vers::UInt32, proc::UInt32, arg_data::Vector{UInt8}=UInt8[], xid::UInt32=UInt32(0x1))
    msg = IOBuffer()
    write(msg, hton(xid))
    write(msg, hton(UInt32(CALL)))
    write(msg, hton(UInt32(2)))       # rpcvers
    write(msg, hton(prog))
    write(msg, hton(vers))
    write(msg, hton(proc))
    # Authentication - only none for now
    write(msg, AUTH_NONE); write(msg, UInt32(0));
    write(msg, AUTH_NONE); write(msg, UInt32(0));
    write(msg, arg_data)
    frame_and_send(c, msg)
    read_reply(c)
end
make_call(c::Channel, prog::Integer, vers::Integer, proc::Integer, arg_data=UInt8[], xid::Integer=0x1) =
    make_call(c, UInt32(prog), UInt32(vers), UInt32(proc), arg_data, UInt32(xid))

function marshal_data(buf::IOBuffer, T::Type, arg)
    if T <: Integer
        # All small integers are promoted to 4 bytes
        if sizeof(T) <= sizeof(UInt32)
            write(buf, hton(arg % UInt32))
        else
            write(buf, hton(arg))
        end
    elseif T <: AbstractString || T == Vector{UInt8}
        size = UInt32(sizeof(arg))
        write(buf, hton(size))
        write(buf, Vector{UInt8}(arg))
        # Pad to 4 byte boundary
        while (size % 4) != 0
            write(buf, UInt8(0))
            size += 1
        end
    else
        for field in fieldnames(T)
            marshal_data(buf, fieldtype(T, field), getfield(arg, field))
        end
    end
    buf
end
marshal_data(t::Type, arg) = take!(marshal_data(IOBuffer(), t, arg))

function demarshal_data(T, reply_buf)
    if T <: Integer
        # All small integers are promoted to 4 bytes
        return if sizeof(T) <= sizeof(UInt32)
            ntoh(read(reply_buf, UInt32)) % T
        else
            ntoh(read(reply_buf, T))
        end
    elseif T <: AbstractString || T == Vector{UInt8}
        ssize = ntoh(read(reply_buf, UInt32))
        str = read(reply_buf, ssize)
        while (ssize % 4) != 0
            read(reply_buf, UInt8)
            ssize += 1
        end
        return T <: AbstractString ? String(str) : str
    else
        args = Any[]
        for field in fieldnames(T)
            push!(args, demarshal_data(fieldtype(T, field), reply_buf))
        end
        return T(args...)
    end
end

function parse_response(T::Type, reply_buf, xid)
    reply_xid = ntoh(read(reply_buf, UInt32))
    (xid == reply_xid) || error("Mismatched XID in reply")
    mt = msg_type(ntoh(read(reply_buf, Int32)))
    (mt == REPLY) || error("Not a REPLY")
    rt = reply_stat(ntoh(read(reply_buf, Int32)))
    (rt == MSG_ACCEPTED) || error("Message was rejected")
    verft = auth_flavor(ntoh(read(reply_buf, UInt32)))
    (verft == AUTH_NONE) || error("Authentication not yet supported")
    verfs = read(reply_buf, UInt32)
    as = accept_stat(ntoh(read(reply_buf, UInt32)))
    (as == SUCCESS) || error("Query failed")
    demarshal_data(T, reply_buf)
end

function make_rpc(prog, vers, proc, ret_type, param_type)
    function(c::Channel, arg)
        arg::param_type
        xid = rand(UInt32)
        reply_buf = make_call(c, prog, vers, proc, marshal_data(param_type, arg), xid)
        parse_response(ret_type, reply_buf, xid)
    end
end

end # module
