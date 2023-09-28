using Documenter, DynamicSparseArrays

makedocs(
    modules = [DynamicSparseArrays],
    sitename = "DynamicSparseArrays",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
    ),
    warnonly = true,
    pages    = Any[
        "Introduction" => "index.md",
        "Sparse Vector" => "vector.md",
        "Sparse Matrix" => "matrix.md",
        "References" => "references.md"
    ]
)

deploydocs(
    repo = "github.com/atoptima/DynamicSparseArrays.jl.git",
    target = "build",
)