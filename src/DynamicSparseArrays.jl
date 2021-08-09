module DynamicSparseArrays

export PackedMemoryArray,
       PackedCSC,
       MappedPackedCSC,
       dynamicsparsevec,
       dynamicsparse,
       nbpartitions,
       deletepartition!,
       deletecolumn!,
       deleterow!,
       addrow!,
       closefillmode!

const Elements{K,T} = Vector{Union{Nothing,Tuple{K,T}}}

include("utils.jl")
include("moves.jl")
include("finds.jl")
include("writes.jl")

include("pma.jl")
include("pcsr.jl")

include("buffer.jl")

include("views.jl")

include("matrix.jl")

include("operations.jl")

end# module
