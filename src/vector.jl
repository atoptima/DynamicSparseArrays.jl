mutable struct DynamicSparseVector{K,T} <: AbstractSparseVector{T,K}
    n::K # length of the vector
    pma::PackedMemoryArray{K,T,NoPredictor}
end

_guess_length(keys::Vector{K}) where K = maximum(keys; init = zero(K))
_guess_length(pma::PackedMemoryArray{K,T,P}) where {K,T,P} =
    mapreduce(e -> e[1], max, pma; init = zero(K))

function _prepare_keys_vals!(keys::Vector{K}, values::Vector{T}, combine::Function) where {K,T}
    @assert length(keys) == length(values)
    length(keys) == 0 && return
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

function _dynamicsparsevec(I, V, combine, n)
    _prepare_keys_vals!(I, V, combine)
    pma = PackedMemoryArray(I, V)
    return DynamicSparseVector(n, pma)
end

function dynamicsparsevec(
    I::Vector{K}, V::Vector{T}, combine::Function, n = _guess_length(I)
) where {T,K}
    applicable(zero, T) || 
        throw(ArgumentError("cannot apply method zero over $(T)"))
    length(I) == length(V) ||
        throw(ArgumentError("keys & nonzeros vectors must have same length."))
    return _dynamicsparsevec(Vector(I), Vector(V), combine, n)
end

dynamicsparsevec(I,V) = dynamicsparsevec(I,V,+)

"""
    dynamicsparsevec(I, V, [combine, n])

Creates a dynamic sparse vector `S` of length `n` such that `S[I[k]] = S[V[k]]`.
The combine operator is used to combine the values of `V` that have same id in `I`.
"""
dynamicsparsevec(I::Vector{K},V,n::K) where K = dynamicsparsevec(I,V,+,n)

shrink_size!(v::DynamicSparseVector) = v.n = _guess_length(v.pma)

# Array interface implementation for the dynamic sparse vector.
Base.ndims(v::DynamicSparseVector) = 1
Base.length(v::DynamicSparseVector) = v.n
Base.size(v::DynamicSparseVector) = (v.n,)
Base.size(v::DynamicSparseVector, i) = size(v)[i]
Base.iterate(v::DynamicSparseVector, state = (eachindex(v.pma.array),)) = iterate(v.pma, state)
Base.lastindex(v::DynamicSparseVector) = lastindex(v.pma)
Base.getindex(v::DynamicSparseVector, key::Integer) = getindex(v.pma, key)
Base.getindex(v::DynamicSparseVector, ::Colon) = v

function Base.setindex!(v::DynamicSparseVector, value, key)
    if !iszero(value)
        v.n = max(v.n, key)
    end
    return setindex!(v.pma, value, key)
end

Base.show(io::IO, v::DynamicSparseVector) = show(io, v.pma)
Base.filter(f, v::DynamicSparseVector) = filter(f, v.pma)

function Base.:(==)(v1::DynVec, v2::DynVec) where {DynVec<:DynamicSparseVector}
    return v1.n == v2.n && v1.pma == v2.pma
end

SparseArrays.nnz(v::DynamicSparseVector) = nnz(v.pma)
Base.copy(::DynamicSparseVector) = error("copy of a dynamic sparse vector not implemented.")

# to use linear algebra:
function SparseArrays.nonzeroinds(v::DynamicSparseVector{K,T}) where {K,T}
    return reduce(v.pma.array; init = K[]) do collection, e
        if !isnothing(e)
            push!(collection, first(e))
        end
        return collection
    end
end

function SparseArrays.nonzeros(v::DynamicSparseVector{K,T}) where {K,T}
    return reduce(v.pma.array; init = T[]) do collection, e
        if !isnothing(e)
            push!(collection, last(e))
        end
        return collection
    end
end 