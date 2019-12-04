using Documenter, DynamicSparseArrays

makedocs(
    modules = [DynamicSparseArrays],
    sitename = "DynamicSparseArrays",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
    ),
    pages    = Any[
        "Introduction" => "index.md"
        #"Home"   => "index.md",
        #"Installation"   => "installation.md",
        #"Quick start"   => "start.md"
    ]
)

deploydocs(
    repo = "github.com/atoptima/DynamicSparseArrays.jl.git",
    target = "build",
)