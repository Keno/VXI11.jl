# create_link
struct Create_LinkParms
    clientId::Int32
    lockDevice::Bool
    lock_timeout::UInt32
    device::String
end

const Device_Link = UInt32
const Device_ErrorCode = UInt32
const Device_Flags = UInt32

struct Create_LinkResp
    error::Device_ErrorCode
    link::Device_Link
    abortPort::UInt16
    maxRecvSize::UInt32
end

const create_link = make_rpc(395183, 1, 10, Create_LinkResp, Create_LinkParms)

# destroy_link
const destroy_link = make_rpc(395183, 1, 23, Device_ErrorCode, Device_Link)

# device_write
struct Device_WriteParms
    lid::Device_Link
    io_timeout::UInt32
    lock_timeout::UInt32
    flags::Device_Flags
    data::Vector{UInt8}
end

struct Device_WriteResp
    error::Device_ErrorCode
    size::UInt32
end

const device_write = make_rpc(395183, 1, 11, Device_WriteResp, Device_WriteParms)

# device_read
struct Device_ReadParms
    lid::Device_Link
    request_size::UInt32
    io_timeout::UInt32
    lock_timeout::UInt32
    flags::Device_Flags
    termChar::UInt8
end

struct Device_ReadResp
    error::Device_ErrorCode
    reason::UInt32
    data::Vector{UInt8}
end

const device_read = make_rpc(395183, 1, 12, Device_ReadResp, Device_ReadParms)
