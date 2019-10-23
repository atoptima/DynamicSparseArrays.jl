struct PackedCompressedSparseRow{K<:Integer,T,P<:AbstractPredictor}
    colptr::Vector{K}      # Column i is in colptr[i]:(colptr[i+1]-1)  
    nzval::PackedMemoryArray{K,T,P}
end

function _dynamicsparse(I, J, V, combine)
    p = sortperm(collect(zip(I,J)))
    permute!(I, p)
    permute!(J, p)
    permute!(V, p)

    @show I
    @show J
    @show V

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
    @show I
    @show J
    @show V
    # TODO 
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

