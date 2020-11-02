# DiskCollections

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://ahnlabb.github.io/DiskCollections.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://ahnlabb.github.io/DiskCollections.jl/dev)
[![Build Status](https://github.com/ahnlabb/DiskCollections.jl/workflows/CI/badge.svg)](https://github.com/ahnlabb/DiskCollections.jl/actions)

Pure Julia, drop-in replacements for collections that persist data on disk. The
idea is to provide similar functionality as
[shelve](https://docs.python.org/3/library/shelve.html) in the python standard
library and the [bplustree](https://github.com/NicolasLM/bplustree) python
module.

## Provided types
At the moment, this package provides two types: `DiskDict` and `LoggingDict`.
They both use an in-memory dict for reads but write data to disk when a value is
stored or deleted. `LoggingDict` writes all dictionary updates linearly
to the disk so the size of the file grow linearly with the number of updates but
the performance of updates remains high even for very large dictionaries.
`DiskDict` writes updates to disk in a similar way but after a certain number of
updates (chosen by the user) it completely reserializes the dictionary so the
file size grows with the size of the actual dictionary instead of the number of
updates.

In addition to storing the data `LoggingDict` also stores the time of each
update. This allows the user to reload the state of the dictionary at any
specified time.


## Considerations and alternatives
For many applications it is important to think carefully about data storage and
the guarantees provided by your chosen storage model. The focus of this library
is to provide a simple (julian) interface and high-performance serialization
that writes the data to disk before making changes in memory. Consequently, the
provided data storage models are suitable when you need recoverability and
inspectability of essentially ephemeral state. Here is a list of a few
alternative Julia modules that aid in data storage.

- [JLD2](https://github.com/JuliaIO/JLD2.jl) - pure Julia, HDF5-compatible (open
  and standardized format, portable to other languages)
- [JSON](https://github.com/JuliaIO/JSON.jl)
  ([JSON2.jl](https://github.com/quinnj/JSON3.jl),
  [JSON3.jl](https://github.com/quinnj/JSON3.jl)) - simple text format,
  human-readable, highly portable
- [SQLite](https://github.com/JuliaDatabases/SQLite.jl) - relational database,
  SQL, highly reliable
- [LibPQ](https://github.com/invenia/LibPQ.jl) - connect to PostgreSQL database
  through libpq
  
More solutions for data storage in Julia can be found in the
[JuliaIO](https://github.com/JuliaIO) and
[JuliaDatabases](https://github.com/JuliaDatabases) organizations.
