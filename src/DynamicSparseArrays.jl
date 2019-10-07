module DynamicSparseArrays

export PackedMemoryArray

mutable struct PackedMemoryArray{K,T}
    capacity::Int
    segment_capacity::Int
    nb_segments::Int
    nb_elements::Int
    height::Int
    t_h::Float64 # upper density treshold at root
    t_0::Float64 # upper density treshold at leaves
    p_h::Float64 # lower density treshold at root
    p_0::Float64 # lower density treshold at leaves
    empty::Vector{Bool} #maybe should be replaced by a nothing ?
    array::Vector{Tuple{K,T}}
end

function PackedMemoryArray{K,T}(capacity::Int) where {K,T}
    seg_capacity = Int(ceil(log2(capacity)))
    nb_segs = Int(ceil(capacity / seg_capacity))
    height = Int(ceil(log2(nb_segs)))
    real_capacity = nb_segs * seg_capacity
    return PackedMemoryArray{K,T}(
        real_capacity, seg_capacity, nb_segs, 0, height, 1.0, 0.75, 0.5, 0.25, 
        ones(Bool, capacity), Vector{Tuple{K,T}}(undef, capacity)
    )
end

# Binary search that returns the position of the key in the array
function _find(pma::PackedMemoryArray{K,T}, key::K)::Int where {K,T}
    from = 1
    to = length(pma.array)
    while from <= to
        mid = (from + to) ÷ 2
        i = mid
        while i >= from && pma.empty[i]
            i -= 1
        end
        if i < from
            from = mid + 1
        else
            if pma.array[i][1] > key
                to = i - 1
            elseif pma.array[i][1] < key
                from = mid + 1
            else
                return i
            end
        end
    end
    i = to
    while i > 0 && pma.empty[i]
        i -= 1
    end
    if i > 0
        return i
    end
    return 0
end


end # module

