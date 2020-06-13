struct DynamicSparseMatrix{K,L,T}
    colmajor::MappedPackedCSC{K,L,T}
    rowmajor::MappedPackedCSC{L,K,T}
end

function dynamicsparse(I::Vector{K}, J::Vector{L}, V::Vector{T}) where {K,L,T}
    return DynamicSparseMatrix(
        dynamicsparsecolmajor(I,J,V), dynamicsparsecolmajor(J,I,V)
    )
end

function Base.setindex!(m::DynamicSparseMatrix{K,L,T}, val, row::K, col::L) where {K,L,T}
    m.colmajor[row, col] = val
    m.rowmajor[col, row] = val
    return m
end

function Base.getindex(m::DynamicSparseMatrix, row, col)
    # TODO : check number of rows & cols
    return m.colmajor[row, col]
end

function Base.view(m::DynamicSparseMatrix{K,L,T}, row::K, ::Colon) where {K,L,T}
    return view(m.rowmajor, :, row)
end

function Base.view(m::DynamicSparseMatrix{K,L,T}, ::Colon, col::L) where {K,L,T}
    return view(m.colmajor, :, col)
end

Base.ndims(m::DynamicSparseMatrix) = 2
Base.length(m::DynamicSparseMatrix) = length(m.rowmajor)
Base.size(m::DynamicSparseMatrix) = (nbpartitions(m.rowmajor), nbpartitions(m.colmajor))

function deletecolumn!(matrix::DynamicSparseMatrix{K,L,T}, col::L) where {K,L,T}
    for (row, val) in @view matrix[:, col]
        matrix.rowmajor[col, row] = zero(T)
    end
    deletecolumn!(matrix.colmajor, col)
    return true
end

function deleterow!(matrix::DynamicSparseMatrix{K,L,T}, row::K) where {K,L,T}
    for (col, val) in @view matrix[row, :]
        matrix.colmajor[row, col] = zero(T)
    end
    deletecolumn!(matrix.rowmajor, col)
    return true
end
