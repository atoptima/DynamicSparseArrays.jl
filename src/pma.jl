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

function _pma(keys::Vector{K}, values::Vector{T}) where {K,T}
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
    array = Vector{Union{Nothing,Tuple{K,T}}}(nothing, capacity)
    for i in 1:nb_elements
        array[i] = (keys[i], values[i])
    end
    pma = PackedMemoryArray(
        capacity, seg_capacity, nb_segs, nb_elements, 0, 0, height, t_h, 
        t_0, p_h, p_0, t_d, p_d, array, NoPredictor()
    )
    _even_rebalance!(pma, 1, capacity, nb_elements)
    return pma
    return 
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

function _insert(pma::PackedMemoryArray, key, value)
    (pos, _) = _find(pma, key)
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

function Base.getindex(pma::PackedMemoryArray{K,T,P}, key) where {K,T,P}
    fpos, fpair = _find(pma, key)
    fpair != nothing && fpair[1] == key && return fpair[2]
    return zero(T)
end

function _dynamicsparsevec(I, V, combine)
    p = sortperm(I)
    permute!(I, p)
    permute!(V, p)
    write_pos = 1
    read_pos = 1
    prev_id = I[read_pos]
    while read_pos < length(I)
        read_pos += 1
        cur_id = I[read_pos]
        if prev_id == cur_id
            V[write_pos] = combine(V[write_pos], V[read_pos])
        else
            write_pos += 1
            if write_pos < read_pos
                I[write_pos] = cur_id
                V[write_pos] = V[read_pos]
            end
        end
        prev_id = cur_id
    end
    resize!(I, write_pos)
    resize!(V, write_pos)
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


mutable struct PartitionedPma{K<:Integer,T<:Real} <: AbstractArray{T,1}
    semaphores::Vector{Int} # pos of the semaphore in the pma
    pma::PackedMemoryArray{K,T,NoPredictor}
end

nbpartitions(ppma::PartitionedPma) = length(ppma.semaphores)
semaphore_key(::Type{K}) where {K<:Integer} = zero(K)

# WARNING : We assume that each partition contains unique keys and is sorted
function PartitionedPackedMemoryArray(keys::Vector{Vector{K}}, values::Vector{Vector{T}}) where {K,T}
    nb_semaphores = length(keys)
    @assert nb_semaphores == length(values)
    ppma_keys = Vector{K}()
    ppma_values = Vector{T}()
    for semaphore_id in 1:nb_semaphores
        # Insert the semaphore 
        push!(ppma_keys, semaphore_key(K))
        push!(ppma_values, T(semaphore_id)) # This is why T <: Real
        # Create the column
        push!(ppma_keys, keys[semaphore_id]...)
        push!(ppma_values, values[semaphore_id]...)
    end
    pma = _pma(ppma_keys, ppma_values)
    semaphores = zeros(Int, nb_semaphores)
    for (pos, pair) in enumerate(pma.array)
        if pair != nothing && pair[1] == semaphore_key(K)
            id = Int(pair[2])
            semaphores[id] = pos
        end
    end
    return PartitionedPma(semaphores, pma)
end