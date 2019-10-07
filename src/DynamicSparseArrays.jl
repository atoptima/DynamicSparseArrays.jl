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

function _emptycell(pma::PackedMemoryArray, pos::Int)
    return pma.empty[pos]
end

function _nextemptycell(pma::PackedMemoryArray, from::Int)
    pos = from + 1
    while !_emptycell(pma, pos) && pos <= pma.capacity 
        pos += 1
    end
    return pos
end

function _previousemptycell(pma::PackedMemoryArray, from::Int)
    pos = from - 1
    while !_emptycell(pma, pos) && pos >= 1
        pos -= 1
    end
    return pos
end

function _movecellstoright(pma::PackedMemoryArray, from::Int, to::Int)
    i = to
    while i >= from
        pma.array[i+1] = pma.array[i]
        pma.empty[i+1] = pma.empty[i]
        i -= 1
    end
    return
end

function _movecellstoleft(pma::PackedMemoryArray, from::Int, to::Int)
    i = to
    while i <= from
        pma.array[i-1] = pma.array[i]
        pma.empty[i-1] = pma.empty[i]
        i += 1
    end
    return
end

function _getkey(pma::PackedMemoryArray, pos::Int)
    if pos == 0 || _emptycell(pma, pos)
        return nothing
    end
    return pma.array[pos][1]
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
        while i >= from && _emptycell(pma, i)
            i -= 1
        end
        if i < from
            from = mid + 1
        else
            curkey = _getkey(pma, i)
            if curkey > key
                to = i - 1
            elseif curkey < key
                from = mid + 1
            else
                return i
            end
        end
    end
    i = to
    while i > 0 && _emptycell(pma, i)
        i -= 1
    end
    if i > 0
        return i
    end
    return 0
end

function _insert(pma::PackedMemoryArray{K,T}, key::K, value::T) where {K,T}
    s = _find(pma, key)
    _getkey(pma, s) == key && return false
    # insert the new key after the one found by the binary search
    nextemptycell = _nextemptycell(pma, s)
    if nextemptycell <= pma.capacity
        _movecellstoright(pma, s+1, nextemptycell)
        pma.array[s+1] = (key, value)
        pma.empty[s+1] = false
    else
        previousemptycell = _previousemptycell(pma, s)
        if previousemptycell >= 1
            _movecellstoleft(pma, s, previousemptycell)
            pma.array[s] = (key, value)
            pma.empty[s] = false 
        else
            error("No empty cell to insert a new element in the PMA.") # Should not occur thanks to density.
        end
    end
    return true
end




end# module

