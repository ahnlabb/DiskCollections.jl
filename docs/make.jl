using DiskCollections
using Documenter

DocMeta.setdocmeta!(DiskCollections, :DocTestSetup, :(using DiskCollections); recursive=true)
makedocs(;
    modules=[DiskCollections],
    authors="Johannes Ahnlide <johannes@voxel.se> and contributors",
    repo="https://github.com/ahnlabb/DiskCollections.jl/blob/{commit}{path}#L{line}",
    sitename="DiskCollections.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://ahnlabb.github.io/DiskCollections.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/ahnlabb/DiskCollections.jl",
)
