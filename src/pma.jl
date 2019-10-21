abstract type AbstractPredictor end

struct NoPredictor <: AbstractPredictor end

# Predictor : TODO later

# Adaptative Packed Memory Array
mutable struct PackedMemoryArray{K,T,P <: AbstractPredictor} <: AbstractArray{T,1}
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
    array::Vector{Union{Nothing,Tuple{K,T}}}
    predictor::P
end

function PackedMemoryArray(keys::Vector{K}, values::Vector{T}) where {K,T}
    @assert length(keys) == length(values)
    t_h, t_0, p_h, p_0 = 0.7, 0.92, 0.3, 0.08
    nb_elements = length(values)
    segment_size_fac = 1
    capacity = 2^ceil(Int, log2(nb_elements/t_h))
    nb_segs = Int(2^ceil(Int, log2(capacity/log2(capacity))) / segment_size_fac)
    seg_capacity = Int(capacity / nb_segs)
    height = Int(log2(nb_segs))
    t_d = (t_h - t_0) / height
    p_d = (p_h - p_0) / height 
    array = Vector{Union{Nothing,Tuple{K,T}}}(nothing, nb_elements)
    for i in 1:nb_elements
        array[i] = (keys[i], values[i])
    end
    sort!(array, by = e -> e[1])
    resize!(array, capacity)
    pma = PackedMemoryArray(
        capacity, seg_capacity, nb_segs, nb_elements, 0, 0, height, t_h, 
        t_0, p_h, p_0, t_d, p_d, array, NoPredictor()
    )
    _even_rebalance!(pma, 1, capacity, nb_elements)
    return pma
end

function _segidofcell(pma::PackedMemoryArray, pos::Int)
    return ((pos - 1) ÷ pma.segment_capacity) + 1
end

function _emptycell(pma::PackedMemoryArray, pos::Int)
    #@assert 1 <= pos <= pma.capacity
    return pma.array[pos] === nothing
end

function _nextemptycellinseg(pma::PackedMemoryArray, from::Int)
    seg_end = _segidofcell(pma, from) * pma.segment_capacity - 1
    pos = from + 1
    while pos <= seg_end
        _emptycell(pma, pos) && return pos
        pos += 1
    end
    return 0
end

function _previousemptycellinseg(pma::PackedMemoryArray, from::Int)
    seg_start = (_segidofcell(pma, from) - 1) * pma.segment_capacity + 1
    pos = from - 1
    while pos >= seg_start
        _emptycell(pma, pos) && return pos
        pos -= 1
    end
    return 0
end

function _movecellstoright!(pma::PackedMemoryArray, from::Int, to::Int)
    #@assert 1 <= from <= to <= pma.capacity
    i = to - 1
    @inbounds while i >= from
        pma.array[i+1] = pma.array[i]
        i -= 1
    end
    return
end

function _movecellstoleft!(pma::PackedMemoryArray, from::Int, to::Int)
    #@assert 1 <= to <= from <= pma.capacity
    i = to + 1
    @inbounds while i <= from
        pma.array[i-1] = pma.array[i]
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
    for pos in from:(to-1)
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
    (pos, val) = _find(pma, key)
    seg = _segidofcell(pma, pos)
    insertion_pos = pos
    if _getkey(pma, pos) == key
        pma.array[pos] = (key, value)
        return false
    end
    # insert the new key after the one found by the binary search
    nextemptycell = _nextemptycellinseg(pma, pos)
    if nextemptycell != 0
        _movecellstoright!(pma, pos+1, nextemptycell)
        pma.array[pos+1] = (key, value)
        insertion_pos += 1
    else
        previousemptycell = _previousemptycellinseg(pma, pos)
        if previousemptycell != 0
            _movecellstoleft!(pma, pos, previousemptycell)
            pma.array[pos] = (key, value)
        else
            error("No empty cell to insert a new element in the PMA.") # Should not occur thanks to density.
        end
    end
    pma.nb_elements += 1
    _look_for_rebalance!(pma, insertion_pos)
    return true
end

# start included, end included
function _even_rebalance!(pma, window_start, window_end, m)
    capacity = window_end - window_start + 1
    if capacity == pma.segment_capacity
        # It is a leaf within the treshold, we stop
        return
    end
    freq = capacity / m
    i = window_start
    j = window_start
    @inbounds while i < window_start + m
        if _emptycell(pma, j)
            j += 1
            continue
        end
        if i < j
            pma.array[i] = pma.array[j]
            pma.array[j] = nothing
        end
        i += 1
        j += 1
    end
    i -= 1
    sum_freq = 0
    @inbounds while i >= window_start
        j = window_end - floor(Int, sum_freq)
        seg = _segidofcell(pma, j)
        if i != j
            pma.array[j] = pma.array[i]
            pma.array[i] = nothing
        end
        i -= 1
        sum_freq += freq  
    end
    return
end

function _look_for_rebalance!(pma::PackedMemoryArray, pos::Int)
    height = 0
    prev_win_start = pos
    prev_win_end = pos - 1
    nb_cells_left = 0
    nb_cells_right = 0
    while height <= pma.height
        window_capacity = 2^height * pma.segment_capacity
        win_start = ((pos - 1) ÷ window_capacity) * window_capacity + 1
        win_end = win_start + window_capacity - 1
        nb_cells_left += _nbcells(pma, win_start, prev_win_start)
        nb_cells_right += _nbcells(pma, prev_win_end + 1, win_end + 1)
        density = (nb_cells_left + nb_cells_right) / window_capacity
        t = pma.t_0 + pma.t_d * height
        if density <= t
            p = pma.p_0 + pma.p_d * height
            nb_cells = nb_cells_left + nb_cells_right
            _even_rebalance!(pma, win_start, win_end, nb_cells)#, p, t)
            return
        end
        prev_win_start = win_start
        prev_win_end = win_end
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
    resize!(pma.array, pma.capacity)
    return
end

Base.ndims(pma::PackedMemoryArray) = 1
Base.size(pma::PackedMemoryArray) = (pma.nb_elements,)
Base.length(pma::PackedMemoryArray) = pma.nb_elements

function Base.setindex!(pma::PackedMemoryArray, value, key)
    return _insert(pma, key, value)
end

function Base.getindex(pma::PackedMemoryArray, key)
    return _find(pma, key)[2]
end
