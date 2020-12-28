mutable struct DynamicSparseMatrix{K,L,T}
    fillmode::Bool
    buffer::Union{Buffer{L,K,T}, Nothing}
    colmajor::Union{MappedPackedCSC{K,L,T}, Nothing}
    rowmajor::Union{MappedPackedCSC{L,K,T}, Nothing}
end

function dynamicsparse(I::Vector{K}, J::Vector{L}, V::Vector{T}) where {K,L,T}
    return DynamicSparseMatrix(
        false, nothing, dynamicsparsecolmajor(I,J,V), dynamicsparsecolmajor(J,I,V)
    )
end

function dynamicsparse(::Type{K}, ::Type{L}, ::Type{T}; fill_mode = true) where {K,L,T}
    return if fill_mode
        DynamicSparseMatrix(
            true, buffer(K,L,T), nothing, nothing
        )
    else
        DynamicSparseMatrix(
            false, nothing, dynamicsparsecolmajor(K,L,T), dynamicsparsecolmajor(K,L,T)
        )
    end
end

function Base.setindex!(m::DynamicSparseMatrix{K,L,T}, val, row::K, col::L) where {K,L,T}
    if m.fillmode
        addelem!(m.buffer, row, col, val)
    else
        m.colmajor[row, col] = val
        m.rowmajor[col, row] = val
    end
    return m
end

function Base.getindex(m::DynamicSparseMatrix, row, col)
    m.fillmode && return m.buffer[row, col]
    # TODO : check number of rows & cols
    return m.colmajor[row, col]
end

function Base.view(m::DynamicSparseMatrix{K,L,T}, row::K, ::Colon) where {K,L,T}
    m.fillmode && error("View of a row not available in fill mode (Open an issue at https://github.com/atoptima/DynamicSparseArrays.jl if you need it).")
    return view(m.rowmajor, :, row)
end

function Base.view(m::DynamicSparseMatrix{K,L,T}, ::Colon, col::L) where {K,L,T}
    m.fillmode && error("View of a column not available in fill mode.")
    return view(m.colmajor, :, col)
end

Base.ndims(m::DynamicSparseMatrix) = 2
Base.length(m::DynamicSparseMatrix) = length(m.rowmajor)
Base.size(m::DynamicSparseMatrix) = (nbpartitions(m.rowmajor), nbpartitions(m.colmajor))

function deletecolumn!(matrix::DynamicSparseMatrix{K,L,T}, col::L) where {K,L,T}
    matrix.fillmode && error("Cannot delete a column in fill mode")
    for (row, val) in @view matrix[:, col]
        matrix.rowmajor[col, row] = zero(T)
    end
    deletecolumn!(matrix.colmajor, col)
    return true
end

function deleterow!(matrix::DynamicSparseMatrix{K,L,T}, row::K) where {K,L,T}
    matrix.fillmode && error("Cannot delete a row in fill mode")
    for (col, val) in @view matrix[row, :]
        matrix.colmajor[row, col] = zero(T)
    end
    deletecolumn!(matrix.rowmajor, row)
    return true
end

function addrow!(
    matrix::DynamicSparseMatrix{K,L,T}, row::L, colids::Vector{K}, vals::Vector{T}
) where {K,L,T}
    if matrix.fillmode
        addrow!(matrix.buffer, row, colids, vals)
    else
        for j in 1:length(colids)
            setindex!(matrix, row, colids[j], vals[j])
        end
    end
    return true
end

function closefillmode!(matrix::DynamicSparseMatrix{K,L,T}) where {K,L,T}
    I, J, V = get_rowids_colids_vals(matrix.buffer)
    matrix.fillmode = false
    matrix.buffer = nothing
    matrix.colmajor = dynamicsparsecolmajor(I,J,V)
    matrix.rowmajor = dynamicsparsecolmajor(J,I,V)
    return true
end