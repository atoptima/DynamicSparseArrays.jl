module DynamicSparseArrays

export PackedMemoryArray

mutable struct PackedMemoryArray{T}
    capacity::Int
    segment_capacity::Int
    nb_segments::Int
    nb_elements::Int
    height::Int
    t_h::Float64 # upper density treshold at root
    t_0::Float64 # upper density treshold at leaves
    p_h::Float64 # lower density treshold at root
    p_0::Float64 # lower density treshold at leaves
    exist::Vector{Bool}
    array::Vector{T}
end

function PackedMemoryArray{T}(capacity::Int) where {T}
    seg_capacity = Int(ceil(log2(capacity)))
    nb_segs = Int(ceil(capacity / seg_capacity))
    height = Int(ceil(log2(nb_segs)))
    real_capacity = nb_segs * seg_capacity
    return PackedMemoryArray{T}(
        real_capacity, seg_capacity, nb_segs, 0, height, 1.0, 0.75, 0.5, 0.25, 
        Vector{T}(undef, capacity), zeros(Bool, capacity)
    )
end

end # module
