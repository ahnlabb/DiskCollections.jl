var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = DiskCollections\nDocTestSetup = quote\n    using DiskCollections\nend","category":"page"},{"location":"#DiskCollections","page":"Home","title":"DiskCollections","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [DiskCollections]","category":"page"},{"location":"#DiskCollections.DiskDict-Union{Tuple{V}, Tuple{K}, Tuple{IO,Int64}} where V where K","page":"Home","title":"DiskCollections.DiskDict","text":"DiskDict{K,V}(io::IO, n::Int; buffered_checkpoint=true)\nDiskDict{K,V}(filename::String, n::Int; buffered_checkpoint=true)\nDiskDict{K,V}(f::Function, filename::String, n::Int; buffered_checkpoint=true)\n\nConstructs a persistent dictionary behaving like a Dict{K,V} that serializes keys and values to the seekable IO io. If a filename is provided instead that file is opened with read, write, and create set to true. Every n updates the dictionary reserializes its current state. If buffered_checkpoint is true, this reserialization is performed in memory before writing the data to the io.\n\nBecause the constructor opens a file that should be closed a function can be provided as the first argument, enabling the use of Do-Block Syntax just as for open.\n\njulia> new_disk_dict = DiskDict(open(\"mydict.jlp\",\"w+\"), 1000)\nDiskDict{Any,Any}()\n\njulia> new_disk_dict[\"name\"] = \"DiskCollections\"\n\"DiskCollections\"\n\njulia> close(new_disk_dict)\n\njulia> plain_dict = DiskDict(\"mydict.jlp\", 1000) do disk_dict\n           Dict(disk_dict)\n       end\nDict{Any,Any} with 1 entry:\n  \"name\" => \"DiskCollections\"\n\n\n\n\n\n","category":"method"},{"location":"#DiskCollections.LoggingDict-Union{Tuple{IO}, Tuple{V}, Tuple{K}} where V where K","page":"Home","title":"DiskCollections.LoggingDict","text":"LoggingDict{K,V}(io::IO; until::Union{DateTime,Nothing}=nothing)\nLoggingDict{K,V}(filename::String; until::Union{DateTime,Nothing}=nothing)\nLoggingDict{K,V}(f::Function, filename::String; until::Union{DateTime,Nothing}=nothing)\n\nConstructs a persistent dictionary behaving like a Dict{K,V} that serializes keys and values to the seekable IO io. If a filename is provided instead that file is opened with read, write, and create set to true. For each update the LoggingDict stores the time; by providing a DateTime for the until parameter of the LoggingDict constructor the updates are loaded from the file up until that point in time.\n\nBecause the constructor opens a file that should be closed a function can be provided as the first argument, enabling the use of Do-Block Syntax just as for open.\n\njulia> using Dates\n\njulia> LoggingDict{Int,String}(\"mylogdict.jlp\") do logdict\n           for i in 1:5\n               logdict[i] = string(i)\n           end\n           sleep(10)\n           for i in 6:10\n               logdict[i] = string(i)\n           end\n       end\n\njulia> LoggingDict{Int,String}(\"mylogdict.jlp\", until=now()-Second(10))\nLoggingDict{Int64,String} with 5 entries:\n  4 => \"4\"\n  2 => \"2\"\n  3 => \"3\"\n  5 => \"5\"\n  1 => \"1\"\n\n\n\n\n\n","category":"method"}]
}
