module DynamicSparseArrays

export PackedMemoryArray,
       PackedCSC,
       MappedPackedCSC,
       dynamicsparsevec,
       dynamicsparse,
       nbpartitions,
       deletepartition!,
       deletecolumn!

const Elements{K,T} = Vector{Union{Nothing,Tuple{K,T}}}

include("utils.jl")
include("moves.jl")
include("finds.jl")
include("writes.jl")

include("pma.jl")
include("pcsr.jl")

include("views.jl")

end# module
