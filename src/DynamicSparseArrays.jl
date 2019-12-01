module DynamicSparseArrays

export dynamicsparsevec, dynamicsparse

export deletepartition!, deletecolumn!

# Partioned Packed Memory Array
export PackedCSC, MappedPackedCSC, nbpartitions

const Elements{K,T} = Vector{Union{Nothing,Tuple{K,T}}}

include("utils.jl")
include("moves.jl")
include("finds.jl")
include("writes.jl")

include("pma.jl")
include("pcsr.jl")

end# module

