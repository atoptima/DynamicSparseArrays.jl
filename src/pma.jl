abstract type AbstractPredictor end

struct NoPredictor <: AbstractPredictor end

# Predictor : TODO later

# Adaptative Packed Memory Array
mutable struct PackedMemoryArray{K,T,P <: AbstractPredictor}
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
    array::Elements{K,T}
    predictor::P
end

# Packed Memory Array constructor
function _array(kv::Vector{Tuple{K,T}}, capacity) where {K,T}
    array = Elements{K,T}(kv)
    resize!(array, capacity)
    return array
end

function _array(keys::Vector{K}, values::Vector{T}, capacity) where {K,T}
    array = Elements{K,T}(nothing, capacity)
    nb_elements = length(values)
    for i in 1:nb_elements
        @inbounds array[i] = (keys[i], values[i])
    end
    return array
end

function _pma(array::Elements{K,T}, nb_elements, t_h, t_0, p_h, p_0) where {K,T}
    capacity = length(array)
    nb_segs = Int(2^ceil(Int, log2(capacity/log2(capacity))))
    seg_capacity = Int(capacity / nb_segs)
    height = Int(log2(nb_segs))
    t_d = (t_h - t_0) / height
    p_d = (p_h - p_0) / height 
    pma = PackedMemoryArray(
        capacity, seg_capacity, nb_segs, nb_elements, 0, 0, height, t_h, 
        t_0, p_h, p_0, t_d, p_d, array, NoPredictor()
    )
    _even_rebalance!(pma, 1, capacity, nb_elements)
    return pma
end

function PackedMemoryArray(kv::Vector{Tuple{K,T}}; sort = true) where {K,T}
    t_h, t_0, p_h, p_0 = 0.7, 0.92, 0.3, 0.08
    nb_elements = length(kv)
    if nb_elements == 0
        return PackedMemoryArray(K, T)
    end
    sort && sort!(kv, by = e -> e[1])
    capacity = 2^ceil(Int, log2(ceil(nb_elements/t_h)))
    array = _array(kv, capacity)
    return _pma(array, nb_elements, t_h, t_0, p_h, p_0)
end

function PackedMemoryArray(keys::Vector{K}, values::Vector{T}; sort = true) where {K,T}
    t_h, t_0, p_h, p_0 = 0.7, 0.92, 0.3, 0.08
    length(keys) == length(values) || ArgumentError("Length keys != length values.")
    nb_elements = length(values)
    if nb_elements == 0
        return PackedMemoryArray(K, T)
    end
    if sort
        p = sortperm(keys)
        permute!(keys, p)
        permute!(values, p)
    end
    capacity = 2^ceil(Int, log2(ceil(nb_elements/t_h)))
    array = _array(keys, values, capacity)
    return _pma(array, nb_elements, t_h, t_0, p_h, p_0)
end

function PackedMemoryArray(::Type{K}, ::Type{T}; expected_nb_elems = 100) where {K,T} # empty pma
    t_h, t_0, p_h, p_0 = 0.7, 0.92, 0.3, 0.08
    capacity = 2^ceil(Int, log2(ceil(expected_nb_elems/t_h)))
    array = Elements{K,T}(nothing, capacity)
    return _pma(array, 0, t_h, t_0, p_h, p_0)
end

# start included, end included
function _even_rebalance!(pma::PackedMemoryArray, window_start, window_end, m)
    capacity = window_end - window_start + 1
    if capacity == pma.segment_capacity
        # It is a leaf within the treshold, we stop
        return
    end
    pack!(pma.array, window_start, window_end, m)
    spread!(pma.array, window_start, window_end, m)
    return
end

function _look_for_rebalance!(pma::PackedMemoryArray, pos::Int)
    p = 0.0
    t = 0.0
    density = 0.0
    height = 0
    prev_win_start = pos
    prev_win_end = pos - 1
    nb_cells_left = 0
    nb_cells_right = 0
    while height <= pma.height
        window_capacity = 2^height * pma.segment_capacity
        win_start = ((pos - 1) ÷ window_capacity) * window_capacity + 1
        win_end = win_start + window_capacity - 1
        nb_cells_left += _nbcells(pma.array, win_start, prev_win_start)
        nb_cells_right += _nbcells(pma.array, prev_win_end + 1, win_end + 1)
        density = (nb_cells_left + nb_cells_right) / window_capacity
        p = pma.p_0 + pma.p_d * height
        t = pma.t_0 + pma.t_d * height
        if p <= density <= t
            nb_cells = nb_cells_left + nb_cells_right
            return win_start, win_end, nb_cells
        end
        prev_win_start = win_start
        prev_win_end = win_end
        height += 1
    end
    nb_cells = nb_cells_left + nb_cells_right
    if density > t 
        _extend!(pma)
    end
    if density < p && pma.height > 1
        # We must pack before shrinking otherwise we loose data
        pack!(pma.array, 1, length(pma.array)/2, nb_cells)
        _shrink!(pma)
    end
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

function _shrink!(pma::PackedMemoryArray)
    pma.capacity /= 2
    pma.nb_segments /= 2
    pma.height -= 1
    pma.t_d = (pma.t_h - pma.t_0) / pma.height
    pma.p_d = (pma.p_h - pma.p_0) / pma.height 
    resize!(pma.array, pma.capacity)
    return
end

SparseArrays.nnz(pma::PackedMemoryArray) = pma.nb_elements

function Base.iterate(pma::PackedMemoryArray, state = (eachindex(getfield(pma, :array)),))
    array = getfield(pma, :array)
    y = iterate(state...)
    y === nothing && return nothing
    return _iterate(array[y[1]], array, (state[1], Base.tail(y)...))
end

function _iterate(curelem::Nothing, array::Elements{K,T}, state) where {K,T}
    y = iterate(state...)
    y === nothing && return nothing
    return _iterate(array[y[1]], array, (state[1], Base.tail(y)...))
end

function _iterate(curelem::Tuple{K,T}, array::Elements{K,T}, state) where {K,T}
    return curelem, state
end

Base.lastindex(pma::PackedMemoryArray) = lastindex(pma.array)

# getindex
function find(pma::PackedMemoryArray{K,T,P}, key::K) where {K,T,P}
    return find(pma.array, key, 1, length(pma.array))
end

function Base.getindex(pma::PackedMemoryArray{K,T,P}, key::K) where {K,T,P}
    _, fpair = find(pma, key)
    fpair !== nothing && fpair[1] == key && return fpair[2]
    return zero(T)
end

# setindex
function Base.setindex!(pma::PackedMemoryArray{K,T,P}, value, key::K) where {K,T,P}  
    if value != zero(T) # We insert
        set_pos, new_elem = insert!(pma.array, key, value, nothing)
        if new_elem
            pma.nb_elements += 1
            win_start, win_end, nbcells = _look_for_rebalance!(pma, set_pos)
            _even_rebalance!(pma, win_start, win_end, nbcells)
        end
    else # We delete
        set_pos, deleted_elem = delete!(pma.array, key)
        if deleted_elem
            pma.nb_elements -= 1
            win_start, win_end, nbcells = _look_for_rebalance!(pma, set_pos)
            _even_rebalance!(pma, win_start, win_end, nbcells)
        end
    end
    return
end

# show TODO : to be improved (issue #1)
function Base.show(io::IO, pma::PackedMemoryArray{K,T,P}) where {K,T,P}
    println(
        io, pma.capacity, "-element ", typeof(pma), " with ", pma.nb_elements, 
        " stored ", pma.nb_elements == 1 ? "entry." : "entries."
    )
    return
end

function Base.filter(f::Function, pma::DynamicSparseArrays.PackedMemoryArray{K,T,P}) where {K,T,P}
    ids = Vector{K}()
    vals = Vector{T}()
    for e in pma
        if f(e)
            push!(ids, e[1])
            push!(vals, e[2])
        end
    end
    return DynamicSparseArrays.dynamicsparsevec(ids, vals)
end

function _arrays_equal(array1::Elements, array2::Elements)
    i = 1
    j = 1
    while i <= length(array1) || j <= length(array2)
        while (i <= length(array1) && array1[i] === nothing) || (j <= length(array2) && array2[j] === nothing)
            if i <= length(array1) && array1[i] === nothing
                i += 1
            end
            if j <= length(array2) && array2[j] === nothing
                j += 1
            end
            if i == length(array1) + 1 && j == length(array2) + 1
                break
            end
        end
        (i > length(array1) && j <= length(array2)) && return false
        (i <= length(array1) && j > length(array2)) && return false
        if i <= length(array1) && j <= length(array2) && array1[i] != array2[j]
            return false
        end
        i += 1
        j += 1
    end
    return true
end

function Base.:(==)(pma1::PackedMemoryArray, pma2::PackedMemoryArray)
    pma1 === pma2 && return true
    pma1.nb_elements != pma2.nb_elements && return false
    return _arrays_equal(pma1.array, pma2.array)
end