hyperceil(x) = 2^ceil(Int,log2(x))
hyperfloor(x) = 2^floor(Int,log2(x))

# TODO
# mutable struct Predictor
#     cells::Array{Tuple{Int,Int,Int}}
# end

# function Predictor(nbcells)

# end

# Adaptative Packed Memory Array
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
        real_capacity, seg_capacity, nb_segs, 0, height, t_h, t_0, p_h, p_0, 
        t_d, p_d, ones(Bool, real_capacity), Vector{Tuple{K,T}}(undef, real_capacity)
    )
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

function _movecellstoright!(pma::PackedMemoryArray, from::Int, to::Int)
    i = to
    while i >= from
        pma.array[i+1] = pma.array[i]
        pma.empty[i+1] = pma.empty[i]
        i -= 1
    end
    return
end

function _movecellstoleft!(pma::PackedMemoryArray, from::Int, to::Int)
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

function _nbcells(pma::PackedMemoryArray, window_start::Int, window_end::Int)
    window_start == window_end && return 0
    nbcells = 0
    for pos in window_start:window_end
        if !_emptycell(pma, pos)
            nbcells += 1
        end
    end
    return nbcells
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
    insertion_pos = s
    _getkey(pma, s) == key && return false
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
    freq = capacity ÷ m
    i = window_start
    for j in window_start:window_end
        if _emptycell(pma, pos) || i == j
            continue
        end
        pma.array[i] = pma.array[j]
        pma.empty[i] = false
        pma.empty[j] = true
        i += 1
    end
    i -= 1
    padding = ceil(Int, (capacity - freq * m) / 2)
    for j in (window_end - padding):-freq:window_start
        pma.array[j] = pma.array[i]
        pma.empty[j] = false
        pma.empty[i] = true
    end
    return
end

function _look_for_rebalance!(pma::PackedMemoryArray, pos::Int)
    height = 0
    prev_window_start = pos
    prev_window_end = pos + 1
    if pos % pma.segment_capacity == 0 # end of segment
        prev_window_start -= 1
        prev_window_pos -= 1
    end
    nb_cells_left = 0
    nb_cells_right = 0
    while height <= pma.height 
        window_capacity = 2^height * pma.segment_capacity
        window_start = pos ÷ window_capacity + 1
        window_end = window_start + window_capacity - 1
        nb_cells_left += _nbcells(pma, window_start, prev_window_start)
        nb_cells_right += _nbcells(pma, prev_window_end, window_end)
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
    # double the size with new right child empty array
    # _unven_rebalance!(pma, 1, pma.capacity)
    return
end