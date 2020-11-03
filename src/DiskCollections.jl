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

"""
    DiskDict{K,V}(io::IO, n::Int; buffered_checkpoint=true)
    DiskDict{K,V}(filename::String, n::Int; buffered_checkpoint=true)
    DiskDict{K,V}(f::Function, filename::String, n::Int; buffered_checkpoint=true)

Constructs a persistent dictionary behaving like a `Dict{K,V}` that serializes
keys and values to the seekable IO `io`. If a filename is provided instead that
file is opened with `read`, `write`, and `create` set to `true`. Every `n`
updates the dictionary reserializes its current state. If `buffered_checkpoint`
is `true`, this reserialization is performed in memory before writing the data
to the io.

Because the constructor opens a file that should be closed a function can be
provided as the first argument, enabling the use of Do-Block Syntax just as for
`open`.

```jldoctest
julia> new_disk_dict = DiskDict(open("mydict.jlp","w+"), 1000)
DiskDict{Any,Any} with 0 entries

julia> new_disk_dict["name"] = "DiskCollections"
"DiskCollections"

julia> close(new_disk_dict)

julia> plain_dict = DiskDict("mydict.jlp", 1000) do disk_dict
           Dict(disk_dict)
       end
Dict{Any,Any} with 1 entry:
  "name" => "DiskCollections"
```
"""
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

"""
    LoggingDict{K,V}(io::IO; until::Union{DateTime,Nothing}=nothing)
    LoggingDict{K,V}(filename::String; until::Union{DateTime,Nothing}=nothing)
    LoggingDict{K,V}(f::Function, filename::String; until::Union{DateTime,Nothing}=nothing)

Constructs a persistent dictionary behaving like a `Dict{K,V}` that serializes
keys and values to the seekable IO `io`. If a filename is provided instead that
file is opened with `read`, `write`, and `create` set to `true`. For each update
the `LoggingDict` stores the time; by providing a `DateTime` for the `until`
parameter of the `LoggingDict` constructor the updates are loaded from the file
up until that point in time.

Because the constructor opens a file that should be closed a function can be
provided as the first argument, enabling the use of Do-Block Syntax just as for
[`open`](@ref).

```jldoctest
julia> using Dates

julia> LoggingDict{Int,String}("mylogdict.jlp") do logdict
           for i in 1:5
               logdict[i] = string(i)
           end
           sleep(10)
           for i in 6:10
               logdict[i] = string(i)
           end
       end

julia> LoggingDict{Int,String}("mylogdict.jlp", until=now()-Second(10))
LoggingDict{Int64,String} with 5 entries:
  4 => "4"
  2 => "2"
  3 => "3"
  5 => "5"
  1 => "1"
```
"""
function LoggingDict{K,V}(io::IO; until::Union{DateTime,Nothing}=nothing) where {K,V}
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
