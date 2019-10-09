hyperceil(x) = 2^ceil(Int,log2(x))
hyperfloor(x) = 2^floor(Int,log2(x))

# TODO
# mutable struct Predictor
#     cells::Array{Tuple{Int,Int,Int}}
# end

# function Predictor(nbcells)

# end

# Adaptative Packed Memory Array
mutable struct PackedMemoryArray{K,T} <: AbstractArray{T,1}
    capacity::Int
    segment_capacity::Int
    nb_segments::Int
    nb_elements::Int
    first_element_pos::Int # for firstindex method
    last_element_pos::Int # for lastindex method
    height::Int
    t_h::Float64 # upper density treshold at root
    t_0::Float64 # upper density treshold at leaves
    p_h::Float64 # lower density treshold at root
    p_0::Float64 # lower density treshold at leaves
    t_d::Float64 # upper density theshold constant
    p_d::Float64 # lower density treshold constant
    empty::Vector{Bool} #maybe should be replaced by a nothing ?
    array::Vector{Tuple{K,T}}
end

function PackedMemoryArray{K,T}(capacity::Int) where {K,T}
    seg_capacity = ceil(Int, log2(capacity))
    nb_segs = hyperceil(capacity / seg_capacity)
    height = log2(nb_segs)
    real_capacity = nb_segs * seg_capacity
    t_h, t_0, p_h, p_0 = 1.0, 0.75, 0.5, 0.25
    t_d = (t_h - t_0) / height
    p_d = (p_h - p_0) / height 
    return PackedMemoryArray{K,T}(
        real_capacity, seg_capacity, nb_segs, 0, 0, 0, height, t_h, t_0, p_h, p_0, 
        t_d, p_d, ones(Bool, real_capacity), Vector{Tuple{K,T}}(undef, real_capacity)
    )
end

function _emptycell(pma::PackedMemoryArray, pos::Int)
    #@assert 1 <= pos <= pma.capacity
    return pma.empty[pos]
end

function _nextemptycell(pma::PackedMemoryArray, from::Int)
    pos = from + 1
    while pos <= pma.capacity && !_emptycell(pma, pos)
        pos += 1
    end
    return pos
end

function _previousemptycell(pma::PackedMemoryArray, from::Int)
    pos = from - 1
    while pos >= 1 && !_emptycell(pma, pos)
        pos -= 1
    end
    return pos
end

function _movecellstoright!(pma::PackedMemoryArray, from::Int, to::Int)
    #@assert 1 <= from <= to <= pma.capacity
    i = to - 1
    while i >= from
        pma.array[i+1] = pma.array[i]
        pma.empty[i+1] = pma.empty[i]
        i -= 1
    end
    return
end

function _movecellstoleft!(pma::PackedMemoryArray, from::Int, to::Int)
    #@assert 1 <= to <= from <= pma.capacity
    i = to + 1
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

# from included, to excluded
function _nbcells(pma::PackedMemoryArray, from::Int, to::Int)
    #@assert 1 <= from <= to <= pma.capacity + 1
    from >= to && return 0
    nbcells = 0
    for pos in from:(to - 1)
        if !_emptycell(pma, pos)
            nbcells += 1
        end
    end
    return nbcells
end

# Binary search that returns the position of the key in the array
function _find(pma::PackedMemoryArray{K,T}, key::K) where {K,T}
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
                return (i, pma.array[i][2])
            end
        end
    end
    i = to
    while i > 0 && _emptycell(pma, i)
        i -= 1
    end
    if i > 0
        return (i, pma.array[i][2])
    end
    return (0, zero(T))
end

function _insert(pma::PackedMemoryArray, key, value)
    (s, val) = _find(pma, key)
    insertion_pos = s
    if _getkey(pma, s) == key
        pma.array[s] = (key, value)
        return false
    end
    # insert the new key after the one found by the binary search
    nextemptycell = _nextemptycell(pma, s)
    if nextemptycell <= pma.capacity
        _movecellstoright!(pma, s+1, nextemptycell)
        pma.array[s+1] = (key, value)
        pma.empty[s+1] = false
        insertion_pos += 1
    else
        previousemptycell = _previousemptycell(pma, s)
        if previousemptycell >= 1
            _movecellstoleft!(pma, s, previousemptycell)
            pma.array[s] = (key, value)
            pma.empty[s] = false 
        else
            error("No empty cell to insert a new element in the PMA.") # Should not occur thanks to density.
        end
    end
    _look_for_rebalance!(pma, insertion_pos)
    return true
end

# Should be in apma.jl
# function _uneven_rebalance!(pma, window_start, window_end, m, p, t)
#     capacity = window_end - window_start + 1
#     if capacity == pma.segment_capacity
#         # It is a leaf within the treshold, we stop
#         return
#     end
#     half_cap = capacity / 2
#     splitnum = max(half_cap * p, m - half_cap * t)
#     # optvalue = 
#     # do things 
#     return
# end

function _even_rebalance!(pma, window_start, window_end, m)
    capacity = window_end - window_start + 1
    if capacity == pma.segment_capacity
        # It is a leaf within the treshold, we stop
        return
    end
    freq = capacity / m
    i = window_start
    for j in window_start:window_end
        _emptycell(pma, j) && continue
        if i != j
            pma.array[i] = pma.array[j]
            pma.empty[i] = false
            pma.empty[j] = true
        end
        i += 1
    end
    padding = ceil(Int, (capacity - (m-2) * freq - 2) / 2)
    i -= 1
    j = window_end - padding
    sum_freq = 0
    while i >= window_start
        j = window_end - padding - floor(Int, sum_freq)
        if i != j
            pma.array[j] = pma.array[i]
            pma.empty[j] = false
            pma.empty[i] = true
        end
        i -= 1
        sum_freq += freq  
    end
    return
end

function _look_for_rebalance!(pma::PackedMemoryArray, pos::Int)
    height = 0
    prev_window_start = pos
    prev_window_end = pos - 1
    nb_cells_left = 0
    nb_cells_right = 0
    while height <= pma.height 
        window_capacity = 2^height * pma.segment_capacity
        window_start = ((pos - 1) ÷ window_capacity) * window_capacity + 1
        window_end = window_start + window_capacity - 1
        nb_cells_left += _nbcells(pma, window_start, prev_window_start)
        nb_cells_right += _nbcells(pma, prev_window_end + 1, window_end + 1)
        density = (nb_cells_left + nb_cells_right) / window_capacity
        t = pma.t_0 + pma.t_d * height
        if density <= t
            p = pma.p_0 + pma.p_d * height
            nb_cells = nb_cells_left + nb_cells_right
            _even_rebalance!(pma, window_start, window_end, nb_cells)#, p, t)
            return
        end
        prev_window_start = window_start
        prev_window_end = window_end
        height += 1
    end
    _extend!(pma)
    nb_cells = nb_cells_left + nb_cells_right
    _even_rebalance!(pma, 1, pma.capacity, nb_cells)
    return
end

function _extend!(pma::PackedMemoryArray)
    pma.capacity *= 2
    pma.nb_segments *= 2
    pma.height += 1
    pma.t_d = (pma.t_h - pma.t_0) / pma.height
    pma.p_d = (pma.p_h - pma.p_0) / pma.height 
    resize!(pma.empty, pma.capacity)
    resize!(pma.array, pma.capacity)
    new_half_start = ceil(Int, pma.capacity / 2)
    for i in new_half_start:pma.capacity
        pma.empty[i] = true
    end
    return
end

Base.ndims(pma::PackedMemoryArray) = 1
Base.size(pma::PackedMemoryArray) = (pma.capacity,)
Base.length(pma::PackedMemoryArray) = pma.nb_elements

function Base.setindex!(pma::PackedMemoryArray, value, key)
    return _insert(pma, key, value)
end

function Base.getindex(pma::PackedMemoryArray, key)
    return _find(pma, key)[2]
end