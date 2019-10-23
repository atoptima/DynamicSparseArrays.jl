struct PackedCompressedSparseRow{K<:Integer,T,P<:AbstractPredictor}
    colptr::Vector{K}      # Column i is in colptr[i]:(colptr[i+1]-1)  
    nzval::PackedMemoryArray{K,T,P}
end

function _dynamicsparse(I, J, V, combine)
    p = sortperm(I)
    permute!(I, p)
    permute!(J, p)
    permute!(V, p)

    @show I
    @show J
    @show V

    write_pos = 1
    read_pos = 1
    # prev_i = x
    # prev_j =  
end

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

