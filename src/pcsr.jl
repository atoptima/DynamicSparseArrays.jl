mutable struct PackedCompSparseColumn{K<:Integer,T<:Real}
    nb_partitions::Int
    semaphores::Vector{Int} # pos of the semaphore in the pma
    #nb_elements_in_partition::Vector{Int} # nb elements after each semaphore
    pma::PackedMemoryArray{K,T,NoPredictor}
end

nbpartitions(pcsc::PackedCompSparseColumn) = length(pcsc.semaphores)
semaphore_key(::Type{K}) where {K<:Integer} = zero(K)

function PartitionedPackedMemoryArray(keys::Vector{Vector{K}}, values::Vector{Vector{T}}, combine::Function = +) where {K,T}
    nb_semaphores = length(keys)
    @assert nb_semaphores == length(values)
    pcsc_keys = Vector{K}()
    pcsc_values = Vector{T}()
    pcsc_elems = Vector{T}()
    for semaphore_id in 1:nb_semaphores
        # Insert the semaphore 
        push!(pcsc_keys, semaphore_key(K))
        push!(pcsc_values, T(semaphore_id)) # This is why T <: Real
        # Create the column
        nkeys = Vector(keys[semaphore_id])
        nvalues = Vector(values[semaphore_id])
        _prepare_keys_vals!(nkeys, nvalues, combine)
        push!(pcsc_keys, nkeys...)
        push!(pcsc_values, nvalues...)
    end
    pma = _pma(pcsc_keys, pcsc_values)
    semaphores = zeros(Int, nb_semaphores)
    for (pos, pair) in enumerate(pma.array)
        if pair != nothing && pair[1] == semaphore_key(K)
            id = Int(pair[2])
            semaphores[id] = pos
        end
    end
    return PackedCompSparseColumn(nb_semaphores, semaphores, pma)
end

Base.ndims(pma::PackedCompSparseColumn) = 2
Base.size(pma::PackedCompSparseColumn) = (10000, 100000)
# Base.length(pma::PackedCompSparseColumn) = pma.nb_elements

function _find(pcsc, partition, key)
    from = pcsc.semaphores[partition]
    to = length(pcsc.pma.array) 
    if partition != pcsc.nb_partitions
        to = pcsc.semaphores[partition + 1] - 1
    end
    return _find(pcsc.pma, key, from, to)
end

function Base.getindex(pcsc::PackedCompSparseColumn{K,T}, partition, key) where {K,T}
    fpos, fpair = _find(pcsc, partition, key)
    fpair != nothing && fpair[1] == key && return fpair[2]
    return zero(T)
end

function Base.setindex!(pcsc::PackedCompSparseColumn{K,T}, value, partition, key) where {K,T}
    from = pcsc.semaphores[partition]
    to = length(pcsc.pma.array) 
    if partition != pcsc.nb_partitions
        to = pcsc.semaphores[partition + 1] - 1
    end
    insertion_pos, rebalance = _insert!(pcsc.pma, key, value, from, to, pcsc.semaphores)
    if rebalance
        win_start, win_end, nbcells = _look_for_rebalance!(pcsc.pma, insertion_pos)
        _even_rebalance!(pcsc, win_start, win_end, nbcells)
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

function _even_rebalance!(pcsc::PackedCompSparseColumn, window_start, window_end, nbcells)
    capacity = window_end - window_start + 1
    if capacity == pcsc.pma.segment_capacity
        # It is a leaf within the treshold, we stop
        return
    end
    _pack!(pcsc.pma.array, window_start, window_end, nbcells)
    _spread!(pcsc.pma.array, window_start, window_end, nbcells, pcsc.semaphores)
    return
end

# struct PackedCompressedSparseColumn{K<:Integer,T,P<:AbstractPredictor}
#     colptr::Vector{K}      # Column i is in colptr[i]:(colptr[i+1]-1)  
#     nzval::PackedMemoryArray{K,T,P}
# end

# function _dynamicsparse(I::Vector{K}, J::Vector{K}, V::Vector{T}, combine) where {K,T}
#     p = sortperm(collect(zip(J,I))) # Columns first
#     permute!(I, p)
#     permute!(J, p)
#     permute!(V, p)

#     write_pos = 1
#     read_pos = 1
#     prev_i = I[read_pos]
#     prev_j = J[read_pos]
#     while read_pos < length(I)
#         read_pos += 1
#         cur_i = I[read_pos]
#         cur_j = J[read_pos]
#         if prev_i == cur_i && prev_j == cur_j
#             V[write_pos] = combine(V[write_pos], V[read_pos])
#         else
#             write_pos += 1
#             if write_pos < read_pos
#                 I[write_pos] = cur_i
#                 J[write_pos] = cur_j
#                 V[write_pos] = V[read_pos]
#             end
#             prev_i = cur_i
#             prev_j = cur_j
#         end
#     end
#     resize!(I, write_pos) 
#     resize!(J, write_pos)
#     resize!(V, write_pos)

#     rows_keys = Vector{Vector{K}}()
#     values = Vector{Vector{T}}()
#     i = 1
#     prev_col = J[1]
#     while i <= length(I)
#         cur_col = J[i]
#         if prev_col != cur_col || i == 1
#             push!(rows_keys, Vector{K}())
#             push!(values, Vector{K}())
#         end
#         push!(rows_keys[end], I[i])
#         push!(values[end], V[i])
#         prev_col = cur_col
#         i += 1
#     end

#     pcsc = PartitionedPackedMemoryArray(rows_keys, values)
#     return pcsc
# end

function dynamicsparse(
    I::Vector{K}, J::Vector{K}, V::Vector{T}, combine::Function
) where {K,T}
    applicable(zero, T) ||
        throw(ArgumentError("cannot apply method zero over $(T)"))
    length(I) == length(J) == length(V) ||
        throw(ArgumentError("rows, columns, & nonzeris"))
    length(I) > 0 ||
        throw(ArgumentError("vectors cannot be empty.")) 
    return _dynamicsparse(Vector(I), Vector(J), Vector(V), combine)
end

dynamicsparse(I,J,V) = dynamicsparse(I,J,V,+) 

