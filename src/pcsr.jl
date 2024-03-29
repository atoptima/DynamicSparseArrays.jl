"""
Matrix whose columns are indexed by an integer.
"""
mutable struct PackedCSC{K,T}
    nb_partitions::Int
    semaphores::Vector{Union{Nothing, Int}} # pos of the semaphore in the pma
    #nb_elements_in_partition::Vector{Int} # nb elements after each semaphore
    pma::PackedMemoryArray{K,T,NoPredictor}
end

SparseArrays.nnz(m::PackedCSC) = nnz(m.pma) - m.nb_partitions

"""
Matrix
"""
mutable struct MappedPackedCSC{K,L,T}
    col_keys::Vector{Union{Nothing, L}} # the position of the key is the position of the column
    pcsc::PackedCSC{K,T}
end

nbpartitions(pcsc::PackedCSC) = pcsc.nb_partitions
nbpartitions(mpcsc::MappedPackedCSC) = nbpartitions(mpcsc.pcsc)
semaphore_key(::Type{K}) where {K<:Integer} = zero(K)
SparseArrays.nnz(m::MappedPackedCSC) = nnz(m.pcsc)

function PackedCSC(
    row_keys::Vector{Vector{L}}, values::Vector{Vector{T}},
    combine::Function = +;
) where {L,T <: Real}
    nb_semaphores = length(row_keys)
    nb_values = sum(length(values[i]) for i in 1:nb_semaphores)
    @assert nb_semaphores == length(values)
    applicable(semaphore_key, L) || error("method `semaphore_key` not implemented for type $(L).")
    pcsc_keys = Vector{L}(undef, nb_values + nb_semaphores)
    pcsc_values = Vector{T}(undef, nb_values + nb_semaphores)
    i = 1
    for semaphore_id in 1:nb_semaphores
        # Insert the semaphore
        @inbounds pcsc_keys[i] = semaphore_key(L)
        @inbounds pcsc_values[i] = T(semaphore_id) # This is why T <: Real
        i += 1
        # Create the column
        @inbounds nkeys = Vector(row_keys[semaphore_id])
        @inbounds nvalues = Vector(values[semaphore_id])
        _prepare_keys_vals!(nkeys, nvalues, combine)
        for j in 1:length(nkeys)
            @inbounds pcsc_keys[i] = nkeys[j]
            @inbounds pcsc_values[i] = nvalues[j]
            i += 1
        end
    end
    resize!(pcsc_keys, i - 1)
    resize!(pcsc_values, i - 1)
    pma = PackedMemoryArray(pcsc_keys, pcsc_values, sort = false)
    semaphores = Vector{Union{Int, Nothing}}(undef, nb_semaphores)
    for (pos, pair) in enumerate(pma.array)
        if pair !== nothing && pair[1] == semaphore_key(L)
            id = Int(pair[2])
            @inbounds semaphores[id] = pos
        end
    end
    return PackedCSC(nb_semaphores, semaphores, pma)
end

function PackedCSC(::Type{K}, ::Type{T}) where {K,T}
    pma = PackedMemoryArray(K, T)
    return PackedCSC(0, Vector{Union{Int, Nothing}}(), pma)
end

PackedCSC(pcsc::PackedCSC) = deepcopy(pcsc)
MappedPackedCSC(mpcsc::MappedPackedCSC) = deepcopy(mpcsc)

function MappedPackedCSC(
    row_keys::Vector{Vector{K}}, column_keys::Vector{L},
    values::Vector{Vector{T}}, combine::Function = +
) where {K,L,T <: Real}
    pcsc = PackedCSC(row_keys, values, combine)
    col_keys = Vector{Union{Nothing,L}}(column_keys)
    return MappedPackedCSC(col_keys, pcsc)
end

function MappedPackedCSC(::Type{K}, ::Type{L}, ::Type{T}) where {K,L,T}
    pcsc = PackedCSC(K, T)
    col_keys = Vector{Union{Nothing, L}}(undef, 0)
    return MappedPackedCSC(col_keys, pcsc)
end

function _even_rebalance!(pcsc::PackedCSC, window_start, window_end, nbcells)
    capacity = window_end - window_start + 1
    if capacity == pcsc.pma.segment_capacity
        # It is a leaf within the treshold, we stop
        return
    end
    pack!(pcsc.pma.array, window_start, window_end, nbcells)
    spread!(pcsc.pma.array, window_start, window_end, nbcells, pcsc.semaphores)
    return
end

function addpartition!(pcsc::PackedCSC{K,T}) where {K,T}
    sem_key = semaphore_key(K)
    sem_pos = length(pcsc.pma.array)
    pcsc.nb_partitions += 1
    push!(pcsc.semaphores, sem_pos)
    sem_val = T(length(pcsc.semaphores))
    insert_pos, new_elem = _insert!(pcsc.pma.array, sem_key, sem_val, sem_pos, pcsc.semaphores)
    if new_elem
        pcsc.pma.nb_elements += 1
        win_start, win_end, nbcells = _look_for_rebalance!(pcsc.pma, insert_pos)
        _even_rebalance!(pcsc, win_start, win_end, nbcells)
    end
    return
end

function addpartition!(pcsc::PackedCSC{K,T}, prev_sem_id::Int) where {K,T}
    semaphores = pcsc.semaphores
    @assert !isnothing(semaphores)
    sem_key = semaphore_key(K)
    nb_semaphores = length(semaphores)
    sem_pos = 0
    semaphore_target = semaphores[prev_sem_id + 1]
    if semaphore_target === nothing
        next_sem_id = _nextnonemptypos(semaphores, prev_sem_id + 1)
        next_semaphore = semaphores[next_sem_id]
        @assert !isnothing(next_semaphore)
        sem_pos = next_semaphore - 1 # insert the new semaphore in the pma.array just before the next one
    else
        sem_pos = semaphore_target - 1 # insert the new semaphore just before the next one
        resize!(semaphores, nb_semaphores + 1) # create room for the position of the new semaphore
        for i in nb_semaphores:-1:(prev_sem_id+1)
            moved_sem_pos = pcsc.semaphores[i]
            semaphores[i+1] = semaphores[i]
            @assert !isnothing(moved_sem_pos)
            pcsc.pma.array[moved_sem_pos] = (sem_key, T(i+1))
        end
    end
    pcsc.nb_partitions += 1
    sem_val = T(prev_sem_id+1)
    insert_pos, new_elem = _insert!(pcsc.pma.array, sem_key, sem_val, sem_pos, pcsc.semaphores)
    semaphores[prev_sem_id+1] = insert_pos
    if new_elem
        pcsc.pma.nb_elements += 1
        win_start, win_end, nbcells = _look_for_rebalance!(pcsc.pma, insert_pos)
        _even_rebalance!(pcsc, win_start, win_end, nbcells)
    end
    return
end

function addcolumn!(mpcsc::MappedPackedCSC{K,L,T}, col::L, prev_col_pos::Int) where {K,L,T}
    col_pos = 0
    if prev_col_pos == length(mpcsc.col_keys) # we add the partition and the semaphore at the end
        push!(mpcsc.col_keys, col)
        addpartition!(mpcsc.pcsc)
        col_pos = length(mpcsc.col_keys)
    else
        if mpcsc.col_keys[prev_col_pos+1] === nothing
            mpcsc.col_keys[prev_col_pos+1] = col
        else
            nbcolkeys = length(mpcsc.col_keys)
            resize!(mpcsc.col_keys, nbcolkeys + 1)
            for i in nbcolkeys:-1:(prev_col_pos+1)
                mpcsc.col_keys[i+1] = mpcsc.col_keys[i]
            end
            mpcsc.col_keys[prev_col_pos+1] = col
        end
        addpartition!(mpcsc.pcsc, prev_col_pos)
        col_pos = prev_col_pos+1
    end
    return col_pos
end

function _pos_of_partition_start(pcsc, partition)
    partition_start_pos = pcsc.semaphores[partition]
    @assert !isnothing(partition_start_pos)
    return partition_start_pos
end

function _pos_of_partition_end(pcsc, partition)
    pos = length(pcsc.pma.array)
    next_partition = _nextnonemptypos(pcsc.semaphores, partition)
    if next_partition != 0
        next_partition_start_pos = pcsc.semaphores[next_partition]
        @assert !isnothing(next_partition_start_pos)
        pos = next_partition_start_pos - 1
    end
    return pos
end

function deletepartition!(pcsc::PackedCSC{K,T}, partition::Int) where {K,T}
    len = length(pcsc.semaphores)
    1 <= partition <= len || throw(BoundsError("cannot access $(len)-elements partition at index [$(partition)]."))
    pcsc.nb_partitions -= 1
    sem_key = semaphore_key(K)
    sem_pos = _pos_of_partition_start(pcsc, partition)
    partition_end_pos = _pos_of_partition_end(pcsc, partition)
    # Delete semaphore & content of the column
    pos, nb_elems_rm = purge!(pcsc.pma.array, sem_pos, partition_end_pos)
    if nb_elems_rm > 0
        pcsc.pma.nb_elements -= nb_elems_rm
        win_start, win_end, nbcells = _look_for_rebalance!(pcsc.pma, pos)
        _even_rebalance!(pcsc, win_start, win_end, nbcells)
    end
    pcsc.semaphores[partition] = nothing
    return
end

function deletecolumn!(mpcsc::MappedPackedCSC{K,L,T}, col::L) where {K,L,T}
    col_pos, col_key = find(mpcsc.col_keys, col)
    col_key != col && throw(ArgumentError("column $(col) does not exist."))
    mpcsc.col_keys[col_pos] = nothing
    deletepartition!(mpcsc.pcsc, col_pos)
    return true
end

Base.ndims(matrix::PackedCSC) = 2
#Base.size(matrix::PackedCSC) = (length(matrix.pma.array), matrix.nb_partitions)

Base.ndims(matrix::MappedPackedCSC) = ndims(matrix.pcsc)
#Base.size(matrix::MappedPackedCSC) = size(matrix.pcsc)


# getindex
function find(pcsc::PackedCSC, partition, key)
    from = _pos_of_partition_start(pcsc, partition)
    to = _pos_of_partition_end(pcsc, partition)
    return find(pcsc.pma.array, key, from, to)
end

function Base.getindex(pcsc::PackedCSC{K,T}, key::K, partition::Int) where {K,T}
    _, fpair = find(pcsc, partition, key)
    fpair !== nothing && fpair[1] == key && return fpair[2]
    return zero(T)
end

function Base.getindex(pcsc::PackedCSC{K,T}, key::K, ::Colon) where {K,T}
    elements = Vector{Tuple{K,T}}()
    partition_id = 0
    sem_key = semaphore_key(K)
    for (k, v) in pcsc.pma
        if k == sem_key
            partition_id = Int(v)
        end
        if k == key
            push!(elements, (partition_id, v))
        end
    end
    pma = PackedMemoryArray(elements)
    return DynamicSparseVector(_guess_length(pma), pma)
end

function Base.getindex(pcsc::PackedCSC{K,T}, ::Colon, partition::Int) where {K,T}
    elements = Vector{Tuple{K,T}}()
    partition_start = _pos_of_partition_start(pcsc, partition) + 1
    partition_end = _pos_of_partition_end(pcsc, partition)
    for elem in pcsc.pma.array[partition_start:partition_end]
        elem !== nothing && push!(elements, elem)
    end
    pma = PackedMemoryArray(elements)
    return DynamicSparseVector(_guess_length(pma), pma)
end

function Base.getindex(mpcsc::MappedPackedCSC{L,K,T}, row::L, col::K) where {L,K,T}
    col_pos, col_key = find(mpcsc.col_keys, col)
    if col_key != col # The column does not exist
        return zero(T)
    end
    return mpcsc.pcsc[row, col_pos]
end

function Base.getindex(mpcsc::MappedPackedCSC{L,K,T}, row::L, ::Colon) where {L,K,T}
    elements = Vector{Tuple{K,T}}()
    partition_id = 0
    sem_key = semaphore_key(L)
    for (k, v) in mpcsc.pcsc.pma
        if k == sem_key
            partition_id = Int(v)
        end
        if k == row
            push!(elements, (mpcsc.col_keys[partition_id], v))
        end
    end
    pma = PackedMemoryArray(elements)
    return DynamicSparseVector(_guess_length(pma), pma)
end

function Base.getindex(mpcsc::MappedPackedCSC{L,K,T}, ::Colon, col::K) where {L,K,T}
    col_pos, col_key = find(mpcsc.col_keys, col)
    if col_key != col # The column does not exist
        return PackedMemoryArray(L,T) # Empty one
    end
    return mpcsc.pcsc[:, col_pos]
end

# setindex
function Base.setindex!(pcsc::PackedCSC{K,T}, value, key::K, partition::Int) where {K,T}
    if partition > length(pcsc.semaphores)
        _add_partitions!(pcsc, partition)
    end
    from = pcsc.semaphores[partition]
    from === nothing && error("The partition has been deleted.")
    to = _pos_of_partition_end(pcsc, partition)
    if value != zero(T)
        # We exclude the semaphore from the subarray in which we insert the new element
        # because otherwise the new element can be inserted at the beginning of the array
        # (see test 3 in unit/finds.jl).
        _insert!(pcsc, value, key, from+1, to)
    else
        _delete!(pcsc, key, from, to)
    end
    return
end

function _add_partitions!(pcsc, nb_part_to_reach)
    p = length(pcsc.semaphores) + 1
    while p <= nb_part_to_reach
        addpartition!(pcsc)
        p += 1
    end
    return
end

function _insert!(pcsc, value, key, from, to)
    insert_pos, new_elem = insert!(pcsc.pma.array, key, value, from, to, pcsc.semaphores)
    if new_elem
        pcsc.pma.nb_elements += 1
        win_start, win_end, nbcells = _look_for_rebalance!(pcsc.pma, insert_pos)
        _even_rebalance!(pcsc, win_start, win_end, nbcells)
    end
    return
end

function _delete!(pcsc, key, from, to)
    set_pos, deleted_elem = delete!(pcsc.pma.array, key, from, to)
    if deleted_elem
        pcsc.pma.nb_elements -= 1
        win_start, win_end, nbcells = _look_for_rebalance!(pcsc.pma, set_pos)
        _even_rebalance!(pcsc, win_start, win_end, nbcells)
    end
    return
end

function Base.setindex!(mpcsc::MappedPackedCSC{L,K,T}, value::T, row::L, col::K) where {L,K,T}
    col_pos, col_key = find(mpcsc.col_keys, col)
    if col_key != col
        col_pos = addcolumn!(mpcsc, col, col_pos)
    end
    return setindex!(mpcsc.pcsc, value, row, col_pos)
end

function Base.setindex!(mpcsc::MappedPackedCSC{L,K,T}, value, row::L, col::K) where {L,K,T}
    return setindex!(mpcsc, T(value), row, col)
end

## Dynamic sparse matrix builder
function _dynamicsparse(
    I::Vector{K}, J::Vector{L}, V::Vector{T}, combine, always_use_map
) where {K,L,T}
    !always_use_map && error("TODO issue #2.")

    ind = collect(zip(J,I))
    p = sortperm(ind, alg=QuickSort) # Columns first
    @inbounds I = I[p]
    @inbounds J = J[p]
    @inbounds V = V[p]

    nb_cols = 1
    nb_rows_in_col = Int[]
    push!(nb_rows_in_col, 1)

    write_pos = 1
    read_pos = 1
    prev_i = I[read_pos]
    prev_j = J[read_pos]
    while read_pos < length(I)
        read_pos += 1
        @inbounds cur_i = I[read_pos]
        @inbounds cur_j = J[read_pos]
        if prev_i == cur_i && prev_j == cur_j
           @inbounds V[write_pos] = combine(V[write_pos], V[read_pos])
        else
            write_pos += 1
            if write_pos < read_pos
                @inbounds I[write_pos] = cur_i
                @inbounds J[write_pos] = cur_j
                @inbounds V[write_pos] = V[read_pos]
            end
            if cur_j != prev_j
                nb_cols += 1
                push!(nb_rows_in_col, 1)
            elseif cur_i != prev_i
                nb_rows_in_col[end] += 1
            end
            prev_i = cur_i
            prev_j = cur_j
        end
    end
    resize!(I, write_pos)
    resize!(J, write_pos)
    resize!(V, write_pos)

    col_keys = Vector{L}(undef, nb_cols)
    row_keys = Vector{Vector{K}}(undef, nb_cols)
    values = Vector{Vector{T}}(undef, nb_cols)
    i = 1
    prev_col = J[1]
    col_pos = 0
    row_pos = 0
    while i <= length(I)
        @inbounds cur_col = J[i]
        if prev_col != cur_col || i == 1
            col_pos += 1
            row_pos = 1
            @inbounds col_keys[col_pos] = cur_col
            @inbounds row_keys[col_pos] = Vector{K}(undef, nb_rows_in_col[col_pos])
            @inbounds values[col_pos] = Vector{T}(undef, nb_rows_in_col[col_pos])
        end
        @inbounds row_keys[col_pos][row_pos] = I[i]
        @inbounds values[col_pos][row_pos] = V[i]
        prev_col = cur_col
        row_pos += 1
        i += 1
    end

    if always_use_map
        return MappedPackedCSC(row_keys, col_keys, values, combine)
    else
        # TODO : Check that we use integer keys for columns, otherwise we have to use a map
        # Add empty columns in the rows_keys vector
        # We can put all those things in a
        return PackedCSC(rows_keys, values, combine)
    end
end

function dynamicsparsecolmajor(
    I::Vector{K}, J::Vector{L}, V::Vector{T}, combine::Function = +,
    always_use_map::Bool = true
) where {K,L,T}
    applicable(zero, T) ||
        throw(ArgumentError("cannot apply method zero over $(T)."))
    length(I) == length(J) == length(V) ||
        throw(ArgumentError("rows, columns, and nonzeros do not have same length."))
    applicable(<, L, L) ||
        throw(ArgumentError("set of keys must be totally ordered (define method Base.:< for type $L)."))
    length(I) > 0 || return dynamicsparsecolmajor(K,L,T)
    return _dynamicsparse(Vector(I), Vector(J), Vector(V), combine, always_use_map)
end

function dynamicsparsecolmajor(::Type{K}, ::Type{L}, ::Type{T}) where {K,L,T}
    return MappedPackedCSC(K,L,T)
end

# Show
# TODO
