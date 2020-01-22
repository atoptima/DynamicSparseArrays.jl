"""
Matrix whose columns are indexed by an integer.
"""
mutable struct PackedCSC{K,T<:Real}
    nb_partitions::Int
    semaphores::Vector{Union{Nothing, Int}} # pos of the semaphore in the pma
    #nb_elements_in_partition::Vector{Int} # nb elements after each semaphore
    pma::PackedMemoryArray{K,T,NoPredictor}
end

"""
Matrix
"""
mutable struct MappedPackedCSC{K,L,T<:Real}
    col_keys::Vector{Union{Nothing, L}} # the position of the key is the position of the column
    pcsc::PackedCSC{K,T}
end

nbpartitions(pcsc::PackedCSC) = length(pcsc.semaphores)
semaphore_key(::Type{K}) where {K<:Integer} = zero(K)

function PackedCSC(
    row_keys::Vector{Vector{L}}, values::Vector{Vector{T}}, 
    combine::Function = +
) where {L,T <: Real}
    nb_semaphores = length(row_keys)
    @assert nb_semaphores == length(values)
    applicable(semaphore_key, L) || error("method `semaphore_key` not implemented for type $(L).")
    pcsc_keys = Vector{L}()
    pcsc_values = Vector{T}()
    for semaphore_id in 1:nb_semaphores
        # Insert the semaphore 
        push!(pcsc_keys, semaphore_key(L))
        push!(pcsc_values, T(semaphore_id)) # This is why T <: Real
        # Create the column
        nkeys = Vector(row_keys[semaphore_id])
        nvalues = Vector(values[semaphore_id])
        _prepare_keys_vals!(nkeys, nvalues, combine)
        push!(pcsc_keys, nkeys...)
        push!(pcsc_values, nvalues...)
    end
    pma = PackedMemoryArray(pcsc_keys, pcsc_values, sort = false)
    semaphores = Vector{Union{Int, Nothing}}(zeros(Int, nb_semaphores))
    for (pos, pair) in enumerate(pma.array)
        if pair != nothing && pair[1] == semaphore_key(L)
            id = Int(pair[2])
            semaphores[id] = pos
        end
    end
    return PackedCSC(nb_semaphores, semaphores, pma)
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
    sem_key = semaphore_key(K)
    nb_semaphores = length(pcsc.semaphores)
    sem_pos = 0
    if pcsc.semaphores[prev_sem_id + 1] === nothing
        next_sem_id = _nextnonemptypos(pcsc.semaphores, prev_sem_id + 1)
        sem_pos = pcsc.semaphores[next_sem_id] - 1 #insert the new semaphore in the pma.array just before the next one
    else 
        sem_pos = pcsc.semaphores[prev_sem_id + 1] - 1 #insert the new semaphore just before the next one
        resize!(pcsc.semaphores, nb_semaphores + 1) # create room for the position of the new semaphore
        for i in nb_semaphores:-1:(prev_sem_id+1)
            moved_sem_pos = pcsc.semaphores[i]
            pcsc.semaphores[i+1] = pcsc.semaphores[i]
            pcsc.pma.array[moved_sem_pos] = (sem_key, T(i+1))
        end
    end
    pcsc.nb_partitions += 1
    sem_val = T(prev_sem_id+1)
    insert_pos, new_elem = _insert!(pcsc.pma.array, sem_key, sem_val, sem_pos, pcsc.semaphores)
    pcsc.semaphores[prev_sem_id+1] = insert_pos
    if new_elem
        pcsc.pma.nb_elements += 1
        win_start, win_end, nbcells = _look_for_rebalance!(pcsc.pma, insert_pos)
        _even_rebalance!(pcsc, win_start, win_end, nbcells)
    end
    return
end

function addcolumn!(mpcsc::MappedPackedCSC{K,L,T}, col::L, prev_col_pos::Int) where {K,L,T}
    col_pos = 0
    if (prev_col_pos == length(mpcsc.col_keys)) # we add the partition and the semaphore at the end
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

_pos_of_partition_start(pcsc, partition) = pcsc.semaphores[partition]
function _pos_of_partition_end(pcsc, partition)
    pos = length(pcsc.pma.array) 
    next_partition = _nextnonemptypos(pcsc.semaphores, partition)
    if next_partition != 0
        pos = pcsc.semaphores[next_partition] - 1
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
    col_key != col && throws(ArgumentError("column $(col) does not exist."))
    mpcsc.col_keys[col_pos] = nothing
    deletepartition!(mpcsc.pcsc, col_pos)
    return true
end

Base.ndims(matrix::PackedCSC) = 2
Base.length(matrix::PackedCSC) = length(matrix.pma) - matrix.nb_partitions
Base.size(matrix::PackedCSC) = (length(matrix.pma.array), matrix.nb_partitions)

Base.ndims(matrix::MappedPackedCSC) = ndims(matrix.pcsc)
Base.length(matrix::MappedPackedCSC) = length(matrix.pcsc)
Base.size(matrix::MappedPackedCSC) = size(matrix.pcsc)


# getindex
function find(pcsc::PackedCSC, partition, key)
    from = _pos_of_partition_start(pcsc, partition)
    to = _pos_of_partition_end(pcsc, partition)
    return find(pcsc.pma.array, key, from, to)
end

function Base.getindex(pcsc::PackedCSC{K,T}, key::K, partition::Int) where {K,T}
    fpos, fpair = find(pcsc, partition, key)
    fpair != nothing && fpair[1] == key && return fpair[2]
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
    return PackedMemoryArray(elements)
end

function Base.getindex(pcsc::PackedCSC{K,T}, ::Colon, partition::Int) where {K,T}
    elements = Vector{Tuple{K,T}}()
    partition_start = _pos_of_partition_start(pcsc, partition) + 1
    partition_end = _pos_of_partition_end(pcsc, partition)
    for elem in pcsc.pma.array[partition_start:partition_end]
        elem !== nothing && push!(elements, elem)
    end
    return PackedMemoryArray(elements)
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
    return PackedMemoryArray(elements)
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
    from == nothing && error("The partition has been deleted.")
    to = _pos_of_partition_end(pcsc, partition)
    if value != zero(T)
        _insert!(pcsc, value, key, from, to)
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


## Dynamic sparse matrix builder (exported)
function _dynamicsparse(
    I::Vector{K}, J::Vector{L}, V::Vector{T}, combine, always_use_map
) where {K,L,T}
    !always_use_map && error("TODO issue #2.")

    p = sortperm(collect(zip(J,I))) # Columns first
    permute!(I, p)
    permute!(J, p)
    permute!(V, p)

    write_pos = 1
    read_pos = 1
    prev_i = I[read_pos]
    prev_j = J[read_pos]
    while read_pos < length(I)
        read_pos += 1
        cur_i = I[read_pos]
        cur_j = J[read_pos]
        if prev_i == cur_i && prev_j == cur_j
            V[write_pos] = combine(V[write_pos], V[read_pos])
        else
            write_pos += 1
            if write_pos < read_pos
                I[write_pos] = cur_i
                J[write_pos] = cur_j
                V[write_pos] = V[read_pos]
            end
            prev_i = cur_i
            prev_j = cur_j
        end
    end
    resize!(I, write_pos) 
    resize!(J, write_pos)
    resize!(V, write_pos)

    col_keys = Vector{L}()
    row_keys = Vector{Vector{K}}()
    values = Vector{Vector{T}}()
    i = 1
    prev_col = J[1]
    while i <= length(I)
        cur_col = J[i]
        if prev_col != cur_col || i == 1
            push!(col_keys, cur_col)
            push!(row_keys, Vector{K}())
            push!(values, Vector{K}())
        end
        push!(row_keys[end], I[i])
        push!(values[end], V[i])
        prev_col = cur_col
        i += 1
    end

    if always_use_map
        return MappedPackedCSC(row_keys, col_keys, values, combine)
    else
        # TODO : Check that we use integer keys for columns, otherwise we have to use a map
        # Add empty columns in the rows_keys vector
        # We can put all those things in a 
        return PackedCSC(rows_keys, values)
    end
end

function dynamicsparse(
    I::Vector{K}, J::Vector{L}, V::Vector{T}, combine::Function, 
    always_use_map::Bool
) where {K,L,T}
    applicable(zero, T) ||
        throw(ArgumentError("cannot apply method zero over $(T)."))
    length(I) == length(J) == length(V) ||
        throw(ArgumentError("rows, columns, & nonzeros do not have same length."))
    length(I) > 0 ||
        throw(ArgumentError("vectors cannot be empty.")) 
    applicable(<, J[1], J[1]) ||
        throw(ArgumentError("set of column keys must be totally ordered (define method Base.:< for type $L)."))
    return _dynamicsparse(
        Vector(I), Vector(J), Vector(V), combine, always_use_map
    )
end

dynamicsparse(I,J,V) = dynamicsparse(I, J, V, +, true) 

# Show
# TODO