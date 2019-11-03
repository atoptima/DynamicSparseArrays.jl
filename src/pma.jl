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
    p = sortperm(keys)
    permute!(keys, p)
    permute!(values, p)
    return _pma(keys, values)
end

function _prepare_keys_vals!(keys::Vector{K}, values::Vector{T}, combine::Function) where {K,T}
    @assert length(keys) == length(values)
    p = sortperm(keys)
    permute!(keys, p)
    permute!(values, p)
    write_pos = 1
    read_pos = 1
    prev_id = keys[read_pos]
    while read_pos < length(keys)
        read_pos += 1
        cur_id = keys[read_pos]
        if prev_id == cur_id
            values[write_pos] = combine(values[write_pos], values[read_pos])
        else
            write_pos += 1
            if write_pos < read_pos
                keys[write_pos] = cur_id
                values[write_pos] = values[read_pos]
            end
        end
        prev_id = cur_id
    end
    resize!(keys, write_pos)
    resize!(values, write_pos)
    return
end

function _pma(keys::Vector{K}, values::Vector{T}) where {K,T}
    t_h, t_0, p_h, p_0 = 0.7, 0.92, 0.3, 0.08
    nb_elements = length(values)
    capacity = 2^ceil(Int, log2(ceil(nb_elements/t_h)))
    nb_segs = Int(2^ceil(Int, log2(capacity/log2(capacity))))
    seg_capacity = Int(capacity / nb_segs)
    height = Int(log2(nb_segs))
    t_d = (t_h - t_0) / height
    p_d = (p_h - p_0) / height 
    array = Vector{Union{Nothing,Tuple{K,T}}}(nothing, capacity)
    for i in 1:nb_elements
        array[i] = (keys[i], values[i])
    end
    max_density = (seg_capacity - 1) / seg_capacity
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
    #seg_end = _segidofcell(pma, from) * pma.segment_capacity
    pos = from + 1
    while pos <= pma.capacity
        _emptycell(pma, pos) && return pos
        pos += 1
    end
    return 0
end

function _previousemptycellinseg(pma::PackedMemoryArray, from::Int)
    #seg_start = (_segidofcell(pma, from) - 1) * pma.segment_capacity + 1
    pos = from - 1
    while pos >= 1
        _emptycell(pma, pos) && return pos
        pos -= 1
    end
    return 0
end

function _movecellstoright!(pma::PackedMemoryArray, from::Int, to::Int, ::Nothing)
    #@assert 1 <= from <= to <= pma.capacity
    i = to - 1
    @inbounds while i >= from
        pma.array[i+1] = pma.array[i]
        i -= 1
    end
    return
end

function _movecellstoleft!(pma::PackedMemoryArray, from::Int, to::Int, ::Nothing)
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
    @assert to <= pma.capacity + 1
    from >= to && return 0
    nbcells = 0
    for pos in from:(to-1)
        if !_emptycell(pma, pos)
            nbcells += 1
        end
    end
    return nbcells
end

# from included, to included
function _find(pma::PackedMemoryArray{K,T}, key::K, from::Int, to::Int) where {K,T}
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
                return (i, pma.array[i])
            end
        end
    end
    i = to
    while i > 0 && _emptycell(pma, i)
        i -= 1
    end
    if i > 0
        return (i, pma.array[i])
    end
    return (0, nothing)
end

# Binary search that returns the position of the key in the array
function _find(pma::PackedMemoryArray{K,T}, key::K) where {K,T}
    return _find(pma, key, 1, length(pma.array))
end

# Insert an element between from and to included
function _insert!(pma::PackedMemoryArray{K,T}, key::K, value::T, from::Int, to::Int, semaphores) where {K,T}
    (pos, _) = _find(pma, key, from, to)
    seg_start = (_segidofcell(pma, pos) - 1) * pma.segment_capacity + 1
    seg_end = _segidofcell(pma, pos) * pma.segment_capacity
    insertion_pos = pos
    if _getkey(pma, pos) == key
        pma.array[pos] = (key, value)
        return (insertion_pos, false)
    end

    # insert the new key after the one found by the binary search
    nextemptycell = _nextemptycellinseg(pma, pos)
    if nextemptycell != 0
        _movecellstoright!(pma, pos+1, nextemptycell, semaphores)
        pma.array[pos+1] = (key, value)
        insertion_pos += 1
    else
        previousemptycell = _previousemptycellinseg(pma, pos)
        if previousemptycell != 0
            _movecellstoleft!(pma, pos, previousemptycell, semaphores)
            pma.array[pos] = (key, value)
        else
            error("No empty cell to insert a new element in the PMA.") # Should not occur thanks to density.
        end
    end
    pma.nb_elements += 1
    return (insertion_pos, true)
end

function _insert!(pma::PackedMemoryArray{K,T}, key::K, value::T, semaphores) where {K,T}
    return _insert!(pma, key, value, 1, length(pma.array), semaphores)
end

# start included, end included
function _pack!(array, window_start, window_end, m)
    i = window_start
    j = window_start
    @inbounds while i < window_start + m
        if array[j] === nothing # empty cell
            j += 1
            continue
        end
        if i < j
            array[i] = array[j]
            array[j] = nothing
        end
        i += 1
        j += 1
    end
    return
end

# start included, end included
function _spread!(array, window_start, window_end, m)
    capacity = window_end - window_start + 1
    nb_empty_cells = capacity - m
    empty_cell_freq = capacity / nb_empty_cells
    next_empty_cell = window_start + floor(nb_empty_cells * empty_cell_freq) - 1
    i = window_start + m - 1
    j = window_end
    @inbounds while i != j && i >= window_start
        if j == next_empty_cell
            nb_empty_cells -= 1
            next_empty_cell = window_start + floor(nb_empty_cells * empty_cell_freq) - 1
            j -= 1
        else
            array[j] = array[i]
            array[i] = nothing
            i -= 1
            j -= 1
        end
    end
    return
end

# start included, end included
function _even_rebalance!(pma::PackedMemoryArray, window_start, window_end, m)
    capacity = window_end - window_start + 1
    if capacity == pma.segment_capacity
        # It is a leaf within the treshold, we stop
        return
    end
    _pack!(pma.array, window_start, window_end, m)
    _spread!(pma.array, window_start, window_end, m)
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
            return win_start, win_end, nb_cells
        end
        prev_win_start = win_start
        prev_win_end = win_end
        height += 1
    end
    _extend!(pma)
    nb_cells = nb_cells_left + nb_cells_right
    return 1, pma.capacity, nb_cells
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
    insertion_pos, rebalance = _insert!(pma, key, value, nothing)
    if rebalance
        win_start, win_end, nbcells = _look_for_rebalance!(pma, insertion_pos)
        _even_rebalance!(pma, win_start, win_end, nbcells)
        return true
    end
    return false
end

function Base.getindex(pma::PackedMemoryArray{K,T,P}, key) where {K,T,P}
    fpos, fpair = _find(pma, key)
    fpair != nothing && fpair[1] == key && return fpair[2]
    return zero(T)
end

function _dynamicsparsevec(I, V, combine)
    _prepare_keys_vals!(I, V, combine)
    return PackedMemoryArray(I, V)
end 

function dynamicsparsevec(I::Vector{K}, V::Vector{T}, combine::Function) where {T,K}
    applicable(zero, T) || 
        throw(ArgumentError("cannot apply method zero over $(T)"))
    length(I) == length(V) ||
        throw(ArgumentError("ids & nonzeros vectors must have same length."))
    length(I) > 0 ||
        throw(ArgumentError("vectors cannot be empty."))
    return _dynamicsparsevec(Vector(I), Vector(V), combine)
end

dynamicsparsevec(I,V) = dynamicsparsevec(I,V,+)

function Base.show(io::IO, pma::PackedMemoryArray{K,T,P}) where {K,T,P}
    println(
        io, pma.capacity, "-element ", typeof(pma), " with ", pma.nb_elements, 
        " stored ", pma.nb_elements == 1 ? "entry." : "entries."
    )
    return
end

mutable struct PartitionedPma{K<:Integer,T<:Real}
    nb_partitions::Int
    semaphores::Vector{Int} # pos of the semaphore in the pma
    #nb_elements_in_partition::Vector{Int} # nb elements after each semaphore
    pma::PackedMemoryArray{K,T,NoPredictor}
end

nbpartitions(ppma::PartitionedPma) = length(ppma.semaphores)
semaphore_key(::Type{K}) where {K<:Integer} = zero(K)

function PartitionedPackedMemoryArray(keys::Vector{Vector{K}}, values::Vector{Vector{T}}, combine::Function = +) where {K,T}
    nb_semaphores = length(keys)
    @assert nb_semaphores == length(values)
    ppma_keys = Vector{K}()
    ppma_values = Vector{T}()
    ppma_elems = Vector{T}()
    for semaphore_id in 1:nb_semaphores
        # Insert the semaphore 
        push!(ppma_keys, semaphore_key(K))
        push!(ppma_values, T(semaphore_id)) # This is why T <: Real
        # Create the column
        nkeys = Vector(keys[semaphore_id])
        nvalues = Vector(values[semaphore_id])
        _prepare_keys_vals!(nkeys, nvalues, combine)
        push!(ppma_keys, nkeys...)
        push!(ppma_values, nvalues...)
    end
    pma = _pma(ppma_keys, ppma_values)
    semaphores = zeros(Int, nb_semaphores)
    for (pos, pair) in enumerate(pma.array)
        if pair != nothing && pair[1] == semaphore_key(K)
            id = Int(pair[2])
            semaphores[id] = pos
        end
    end
    return PartitionedPma(nb_semaphores, semaphores, pma)
end

Base.ndims(pma::PartitionedPma) = 2
Base.size(pma::PartitionedPma) = (10000, 100000)
# Base.length(pma::PartitionedPma) = pma.nb_elements

function _find(ppma, partition, key)
    from = ppma.semaphores[partition]
    to = length(ppma.pma.array) 
    if partition != ppma.nb_partitions
        to = ppma.semaphores[partition + 1] - 1
    end
    return _find(ppma.pma, key, from, to)
end

function Base.getindex(ppma::PartitionedPma{K,T}, partition, key) where {K,T}
    fpos, fpair = _find(ppma, partition, key)
    fpair != nothing && fpair[1] == key && return fpair[2]
    return zero(T)
end

function Base.setindex!(ppma::PartitionedPma{K,T}, value, partition, key) where {K,T}
    from = ppma.semaphores[partition]
    to = length(ppma.pma.array) 
    if partition != ppma.nb_partitions
        to = ppma.semaphores[partition + 1] - 1
    end
    insertion_pos, rebalance = _insert!(ppma.pma, key, value, from, to, ppma.semaphores)
    if rebalance
        win_start, win_end, nbcells = _look_for_rebalance!(ppma.pma, insertion_pos)
        _even_rebalance!(ppma, win_start, win_end, nbcells)
    end
    return 
end

function _spread!(array, window_start, window_end, m, semaphores)
    capacity = window_end - window_start + 1
    nb_empty_cells = capacity - m
    empty_cell_freq = capacity / nb_empty_cells
    next_empty_cell = window_start + floor(nb_empty_cells * empty_cell_freq) - 1
    i = window_start + m - 1
    j = window_end
    @inbounds while i >= window_start
        if j == next_empty_cell
            nb_empty_cells -= 1
            next_empty_cell = window_start + floor(nb_empty_cells * empty_cell_freq) - 1
            j -= 1
        else
            if i != j
                array[j] = array[i]
                array[i] = nothing
            end
            (key, val) = array[j]
            if key == semaphore_key(typeof(key))
                semaphores[Int(val)] = j
            end
            i -= 1
            j -= 1
        end
    end
    return
end


function _movecellstoright!(pma::PackedMemoryArray{K,T}, from::Int, to::Int, semaphores) where {K,T}
    #@assert 1 <= from <= to <= pma.capacity
    i = to - 1
    @inbounds while i >= from
        (key, val) = pma.array[i]
        pma.array[i+1] = (key, val)
        if key == semaphore_key(typeof(key))
            semaphores[Int(val)] = i+1
        end
        i -= 1
    end
    return
end

function _movecellstoleft!(pma::PackedMemoryArray{K,T}, from::Int, to::Int, semaphores) where {K,T}
    #@assert 1 <= to <= from <= pma.capacity
    i = to + 1
    @inbounds while i <= from
        (key, val) = pma.array[i]
        pma.array[i-1] = (key, val)
        if key == semaphore_key(typeof(key))
            semaphores[Int(val)] = i-1
        end
        i += 1
    end
    return
end

function _even_rebalance!(ppma::PartitionedPma, window_start, window_end, nbcells)
    capacity = window_end - window_start + 1
    if capacity == ppma.pma.segment_capacity
        # It is a leaf within the treshold, we stop
        return
    end
    _pack!(ppma.pma.array, window_start, window_end, nbcells)
    _spread!(ppma.pma.array, window_start, window_end, nbcells, ppma.semaphores)
    return
end