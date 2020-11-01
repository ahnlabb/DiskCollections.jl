module DiskCollections
using Serialization
using Dates

export DiskDict, LoggingDict, checkpoint!, update_key

abstract type AbstractDiskDict{K,V} <: AbstractDict{K,V} end
mutable struct DiskDict{K,V} <: AbstractDiskDict{K,V}
    cache::Dict{K,V}
    s::Serializer
    io::IO
    n::Int
    counter::Int
    buffered_checkpoint::Bool
end

@enum ActionTag setaction deleteaction

function init_dict(K,V,io)
    seek(io, 0)
    s = Serializer(io)
    dict::Dict{K,V} = if eof(io)
        d = Dict{K,V}()
        serialize(s, d)
        d
    else
        deserialize(s)
    end
    s, dict
end

function DiskDict{K,V}(io::IO, n::Int; buffered_checkpoint=true) where {K,V}
    s, cache = init_dict(K,V,io)
    counter = 0
    while !eof(io)
        tag = read(io, UInt8)
        if tag == UInt8(deleteaction)
            key = deserialize(s)
            delete!(cache, key)
        elseif tag == UInt8(setaction)
            key = deserialize(s)
            value = deserialize(s)
            cache[key] = value
        end
        counter += 1
    end
    DiskDict(cache, s, io, n, counter, buffered_checkpoint)
end

function DiskDict{K,V}(filename::String, n::Int; kwargs...) where {K,V}
    io = open(filename, create=true, read=true, write=true)
    DiskDict{K,V}(io, n; kwargs...)
end

function DiskDict{K,V}(f::Function, filename::String, args...; kwargs...) where {K,V}
    open(filename, create=true, read=true, write=true) do io
        f(DiskDict{K,V}(io, args...; kwargs...))
    end
end

DiskDict(args...; kwargs...) = DiskDict{Any,Any}(args...; kwargs...)

Base.close(dict::DiskDict) = close(dict.io)
Base.isopen(dict::DiskDict) = isopen(dict.io)

Base.length(dict::AbstractDiskDict) = length(dict.cache)
Base.iterate(dict::AbstractDiskDict, state...) = iterate(dict.cache, state...)
Base.getindex(dict::AbstractDiskDict{K,V}, key::K) where {K,V} = dict.cache[key]

function Base.setindex!(h::DiskDict{K,V}, v0, key0) where {K,V}
    key = convert(K, key0)
    if !isequal(key, key0)
        throw(ArgumentError("$(Base.limitrepr(key0)) is not a valid key for type $K"))
    end
    setindex!(h, v0, key)
end

function Base.setindex!(dict::DiskDict{K,V}, value, key::K) where {K,V}
    v = convert(V, value)
    if dict.counter >= dict.n
        checkpoint!(dict)
    end

    write_action(dict, setaction, key, v)
    dict.counter += 1

    dict.cache[key] = v
end

update_key(h::AbstractDiskDict, key) = setindex!(h, key, h[key])

function write_action(coll, action::ActionTag, args...)
    write(coll.io, UInt8(action))
    for a in args
        serialize(coll.s, a)
    end
    flush(coll.io)
end

function checkpoint!(dict::DiskDict)
    seek(dict.io, 0)
    if dict.buffered_checkpoint
        buf = IOBuffer()
        serialize(Serializer(buf), dict.cache)
        write(dict.io, take!(buf))
    else
        serialize(Serializer(dict.io), dict.cache)
    end
    truncate(dict.io, position(dict.io))
    dict.s = Serializer(dict.io)
    flush(dict.io)
    dict.counter = 0
end

function Base.delete!(dict::DiskDict, key)
    if dict.counter >= dict.n
        checkpoint!(dict)
    end
    write_action(dict, deleteaction, key)
    dict.counter += 1

    delete!(dict.cache, key)
end

function Base.pop!(dict::AbstractDiskDict, key)
    v = dict.cache[key]
    delete!(dict, key)
    return v
end

mutable struct LoggingDict{K,V} <: AbstractDiskDict{K,V}
    cache::Dict{K,V}
    s::Serializer
    io::IO
    log_start::Int
end

function LoggingDict{K,V}(io::IO; until=nothing) where {K,V}
    s, cache = init_dict(K,V,io)
    log_start = position(io)
    while !eof(io)
        datetime = unix2datetime(read(io, Float64))
        if !isnothing(until) && datetime > until
            break
        end
        tag = read(io, UInt8)
        if tag == UInt8(deleteaction)
            key = deserialize(s)
            delete!(cache, key)
        elseif tag == UInt8(setaction)
            key = deserialize(s)
            value = deserialize(s)
            cache[key] = value
        end
    end
    LoggingDict(cache, s, io, log_start)
end

function Base.delete!(dict::LoggingDict, key)
    write_action(dict, deleteaction, key)
    delete!(dict.cache, key)
end

function Base.setindex!(dict::LoggingDict{K,V}, value, key::K) where {K,V}
    v = convert(V, value)

    write(dict.io, datetime2unix(now()))
    write_action(dict, setaction, key, v)

    dict.cache[key] = v
end

function LoggingDict{K,V}(filename::String; kwargs...) where {K,V}
    io = open(filename, create=true, read=true, write=true)
    LoggingDict{K,V}(io; kwargs...)
end

function LoggingDict{K,V}(f::Function, filename::String, args...; kwargs...) where {K,V}
    open(filename, create=true, read=true, write=true) do io
        f(LoggingDict{K,V}(io, args...; kwargs...))
    end
end

LoggingDict(args...; kwargs...) = LoggingDict{Any,Any}(args...; kwargs...)

end
