module DynamicSparseArrays

export dynamicsparsevec, dynamicsparse

# Partioned Packed Memory Array
export PackedCSC, nbpartitions

include("moves.jl")

include("pma.jl")
include("pcsr.jl")

end# module

