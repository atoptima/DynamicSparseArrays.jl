hyperceil(x) = 2^ceil(Int,log2(x))
hyperfloor(x) = 2^floor(Int,log2(x))

# TODO
# mutable struct Predictor
#     cells::Array{Tuple{Int,Int,Int}}
# end

# function Predictor(nbcells)

# end

abstract type AbstractPredictor end

struct NoPredictor <: AbstractPredictor end

# Adaptative Packed Memory Array
mutable struct PackedMemoryArray{K,T,P <: AbstractPredictor} <: AbstractArray{T,1}
    capacity::Int
    segment_capacity::Int
    nb_segments::Int
    element_counters::Vector{Int} # nb elements in given segment
    first_element_pos::Int # for firstindex method
    last_element_pos::Int # for lastindex method
    height::Int
    t_h::Float64 # upper density treshold at root
    t_0::Float64 # upper density treshold at leaves
    p_h::Float64 # lower density treshold at root
    p_0::Float64 # lower density treshold at leaves
    t_d::Float64 # upper density theshold constant
    p_d::Float64 # lower density treshold constant
    #empty::Vector{Bool} #maybe should be replaced by a nothing ?
    array::Vector{Union{Nothing,Tuple{K,T}}}
    predictor::P
end

function PackedMemoryArray{K,T}(capacity::Int) where {K,T}
    seg_capacity = ceil(Int, log2(capacity))
    nb_segs = hyperceil(capacity / seg_capacity)
    height = Int(log2(nb_segs))
    real_capacity = nb_segs * seg_capacity
    t_h, t_0, p_h, p_0 = 0.92, 0.7, 0.3, 0.08
    t_d = (t_h - t_0) / height
    p_d = (p_h - p_0) / height 
    element_counters = zeros(Int, nb_segs)
    return PackedMemoryArray(
        real_capacity, seg_capacity, nb_segs, element_counters, 0, 0, height, 
        t_h, t_0, p_h, p_0, t_d, p_d, 
        Vector{Union{Nothing,Tuple{K,T}}}(nothing, real_capacity),
        NoPredictor()
    )
end

function PackedMemoryArray(keys::Vector{K}, values::Vector{T}) where {K,T}
    @assert length(keys) == length(values)
    t_h, t_0, p_h, p_0 = 0.92, 0.7, 0.3, 0.08
    nb_elements = length(values)
    min_capacity = floor(Int, nb_elements / p_h)
    seg_capacity = ceil(Int, log2(min_capacity))
    nb_segs = hyperceil(min_capacity / seg_capacity)
    height = Int(log2(nb_segs))
    capacity = nb_segs * seg_capacity
    t_d = (t_h - t_0) / height
    p_d = (p_h - p_0) / height 
    array = Vector{Union{Nothing,Tuple{K,T}}}(nothing, nb_elements)
    for i in 1:nb_elements
        array[i] = (keys[i], values[i])
    end
    sort!(array, by = e -> e[1])
    resize!(array, capacity)
    element_counters = zeros(Int, nb_segs)
    nb_full_seg = nb_elements ÷ nb_segs
    element_counters[1:nb_full_seg] .= seg_capacity
    element_counters[nb_full_seg + 1] = nb_elements % nb_segs
    pma = PackedMemoryArray(
        capacity, seg_capacity, nb_segs, element_counters, 0, 0, height, t_h, 
        t_0, p_h, p_0, t_d, p_d, array, NoPredictor()
    )
    _even_rebalance!(pma, 1, nb_segs + 1, nb_elements)
    #_debug_check_all_counters(pma)
    return pma
end

function _segidofcell(pma::PackedMemoryArray, pos::Int)
    return ((pos - 1) ÷ pma.segment_capacity) + 1
end

function _emptycell(pma::PackedMemoryArray, pos::Int)
    #@assert 1 <= pos <= pma.capacity
    return pma.array[pos] == nothing
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
function _nbcellsinseg(pma::PackedMemoryArray, from::Int, to::Int)
    @assert 1 <= from <= to <= pma.capacity + 1
    from >= to && return 0
    nbcells = 0
    for seg in from:(to - 1)
        nbcells += pma.element_counters[seg]
    end
    return nbcells
end

# from included, to excluded
function _nbcells(pma::PackedMemoryArray, from::Int, to::Int)
    #@assert 1 <= from <= to <= pma.capacity + 1
    from >= to && return 0
    nbcells = 0
    for pos in from:to
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
    #println("\e[32m -------- insert ($key, $value)--------- \e[00m")
    (pos, val) = _find(pma, key)
    insertion_pos = pos
    if _getkey(pma, pos) == key
        pma.array[pos] = (key, value)
        return false
    end
    # insert the new key after the one found by the binary search
    nextemptycell = _nextemptycellinseg(pma, pos)
    if nextemptycell != 0
        #println(">>> found empty cell @N $nextemptycell in segment $(_segidofcell(pma, nextemptycell))")
        _movecellstoright!(pma, pos+1, nextemptycell)
        seg = _segidofcell(pma, pos+1)
        pma.array[pos+1] = (key, value)
        insertion_pos += 1
    else
        previousemptycell = _previousemptycellinseg(pma, pos)
        if previousemptycell != 0
            #println(">>> found empty cell @P $previousemptycell in segment $(_segidofcell(pma, previousemptycell))")
            seg = _segidofcell(pma, pos)
            _movecellstoleft!(pma, pos, previousemptycell)
            pma.array[pos] = (key, value)
        else
            #error("No empty cell to insert a new element in the PMA.") # Should not occur thanks to density.
        end
    end
    #println(">>>> ELEMENT INSERTED in segment $seg")
    pma.element_counters[seg] += 1
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

# start included, end excluded
function _even_rebalance!(pma, seg_window_start, seg_window_end, m)
    #println("**************************")
    # @show seg_window_start
    # @show seg_window_end
    window_start = (seg_window_start - 1) * pma.segment_capacity + 1
    window_end = (seg_window_end - 1) * pma.segment_capacity
    capacity = window_end - window_start + 1
    # println("******* even rebalance *******")
    # @show seg_window_start
    # @show seg_window_end
    # @show pma.segment_capacity
    # @show pma.nb_segments
    # @show pma.capacity
    # @show window_start
    # @show window_end
    # @show capacity
    # @show m
    # @show _nbcells(pma,window_start,window_end)
    # @show pma.array[window_start:window_end]
    # @assert m == _nbcells(pma,window_start,window_end)
    # println("******************************")
    if capacity == pma.segment_capacity
        # It is a leaf within the treshold, we stop
        return
    end
    for seg in seg_window_start:(seg_window_end - 1)
        pma.element_counters[seg] = 0
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
        #println("---- moving $i to $j ($(_segidofcell(pma, j))).")
        pma.element_counters[seg] += 1
        i -= 1
        sum_freq += freq  
    end
    return
end

function _look_for_rebalance!(pma::PackedMemoryArray, pos::Int)
    height = 0
    seg_of_pos = _segidofcell(pma, pos)
    prev_seg_win_start = seg_of_pos
    prev_seg_win_end = seg_of_pos
    nb_cells_left = 0
    nb_cells_right = 0
    while height <= pma.height 
        window_capacity = 2^height * pma.segment_capacity
        seg_window_start = ((seg_of_pos - 1) ÷ 2^height) * 2^height + 1
        seg_window_end = seg_window_start + 2^height
        # println("**** rebalance ****")
        # @show height
        # @show pos
        # @show window_start
        # @show window_end
        # println("********************")
        nb_cells_left += _nbcellsinseg(pma, seg_window_start, prev_seg_win_start)
        nb_cells_right += _nbcellsinseg(pma, prev_seg_win_end, seg_window_end)
        density = (nb_cells_left + nb_cells_right) / window_capacity
        t = pma.t_0 + pma.t_d * height
        if density <= t
            p = pma.p_0 + pma.p_d * height
            nb_cells = nb_cells_left + nb_cells_right
            _even_rebalance!(pma, seg_window_start, seg_window_end, nb_cells)#, p, t)
            #_debug_check_all_counters(pma)
            return
        end
        prev_seg_win_start = seg_window_start
        prev_seg_win_end = seg_window_end
        height += 1
    end
    _extend!(pma)
    nb_cells = nb_cells_left + nb_cells_right
    _even_rebalance!(pma, 1, pma.nb_segments + 1, nb_cells)
    #_debug_check_all_counters(pma)
    return
end

function _extend!(pma::PackedMemoryArray)
    pma.capacity *= 2
    pma.nb_segments *= 2
    pma.height += 1
    pma.t_d = (pma.t_h - pma.t_0) / pma.height
    pma.p_d = (pma.p_h - pma.p_0) / pma.height 
    resize!(pma.array, pma.capacity)
    resize!(pma.element_counters, pma.nb_segments)
    new_half_start = pma.nb_segments ÷ 2 + 1
    pma.element_counters[new_half_start:pma.nb_segments] .= 0
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


### Methods for debug purposes
function _debug_check_all_counters(pma)
    for (seg, val) in enumerate(pma.element_counters)
        window_start = (seg - 1) * pma.segment_capacity + 1
        window_end = (seg) * pma.segment_capacity - 1
        println("segment $seg contains $(_nbcells(pma, window_start, window_end+1)) and val = $val")
        @show pma.array[window_start:window_end]
        @assert val == _nbcells(pma, window_start, window_end+1)
    end
    return
end