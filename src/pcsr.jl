mutable struct PackedCSC{K,T<:Real}
    nb_partitions::Int
    semaphores::Vector{Int} # pos of the semaphore in the pma
    #nb_elements_in_partition::Vector{Int} # nb elements after each semaphore
    pma::PackedMemoryArray{K,T,NoPredictor}
end

mutable struct MappedPackedCSC{K,L,T<:Real}
    col_keys::Vector{L} # the position of the key is the position of the column
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
    pma = _pma(pcsc_keys, pcsc_values)
    semaphores = zeros(Int, nb_semaphores)
    for (pos, pair) in enumerate(pma.array)
        if pair != nothing && pair[1] == semaphore_key(L)
            id = Int(pair[2])
            semaphores[id] = pos
        end
    end
    return PackedCSC(nb_semaphores, semaphores, pma)
end

function MappedPackedCSC(
    row_keys::Vector{Vector{K}}, column_keys::Vector{L}, 
    values::Vector{Vector{T}}, combine::Function = +
) where {K,L,T <: Real}
    pcsc = PackedCSC(row_keys, values, combine)
    return MappedPackedCSC(column_keys, pcsc)
end

function _even_rebalance!(pcsc::PackedCSC, window_start, window_end, nbcells)
    capacity = window_end - window_start + 1
    if capacity == pcsc.pma.segment_capacity
        # It is a leaf within the treshold, we stop
        return
    end
    _pack!(pcsc.pma.array, window_start, window_end, nbcells)
    _spread!(pcsc.pma.array, window_start, window_end, nbcells, pcsc.semaphores)
    return
end

function addpartition!(pcsc::PackedCSC{K,T}) where {K,T}
    sem_key = semaphore_key(K)
    sem_pos = length(pcsc.pma.array)
    pcsc.nb_partitions += 1
    sem_val = T(pcsc.nb_partitions)
    push!(pcsc.semaphores, sem_pos)
    return _insert!(
        pcsc.pma.array, sem_key, sem_val, sem_pos, pcsc.pma.segment_capacity,
        pcsc.semaphores
    )
end


Base.ndims(pma::PackedCSC) = 2
Base.size(pma::PackedCSC) = (10000, 100000)
# Base.length(pma::PackedCSC) = pma.nb_elements


# getindex
function find(pcsc::PackedCSC, partition, key)
    from = pcsc.semaphores[partition]
    to = length(pcsc.pma.array) 
    if partition != pcsc.nb_partitions
        to = pcsc.semaphores[partition + 1] - 1
    end
    return find(pcsc.pma.array, key, from, to)
end

function Base.getindex(pcsc::PackedCSC{K,T}, key::K, partition::Int) where {K,T}
    fpos, fpair = find(pcsc, partition, key)
    fpair != nothing && fpair[1] == key && return fpair[2]
    return zero(T)
end

function Base.getindex(mpcsc::MappedPackedCSC{L,K,T}, row::L, col::K) where {L,K,T}
    col_pos = findfirst(col_key -> col_key == col, mpcsc.col_keys)
    if col_pos == nothing # The column does not exist
        return zero(T)
    end
    return mpcsc.pcsc[row, col_pos]
end


# setindex 
function Base.setindex!(pcsc::PackedCSC{K,T}, value, key::K, partition::Int) where {K,T}
    from = pcsc.semaphores[partition]
    to = length(pcsc.pma.array) 
    if partition != pcsc.nb_partitions
        to = pcsc.semaphores[partition + 1] - 1
    end
    insert_pos, new_elem = insert!(
        pcsc.pma.array, key, value, from, to, pcsc.pma.segment_capacity, 
        pcsc.semaphores
    )
    if new_elem
        pcsc.pma.nb_elements += 1
        win_start, win_end, nbcells = _look_for_rebalance!(pcsc.pma, insert_pos)
        _even_rebalance!(pcsc, win_start, win_end, nbcells)
    end
    return 
end

function Base.setindex!(mpcsc::MappedPackedCSC{L,K,T}, value::T, row::L, col::K) where {L,K,T}
    col_pos = findfirst(col_key -> col_key == col, mpcsc.col_keys)
    if col_pos == nothing
        last_col = mpcsc.col_keys[end]
        col <= last_col && throw(ArgumentError("New column must have id greater than last column id; got id $(col), last column id is $(last_col)."))
        push!(mpcsc.col_keys, col)
        addpartition!(mpcsc.pcsc)
        col_pos = length(mpcsc.col_keys) 
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