mutable struct DynamicSparseMatrix{K,L,T}
    m::K # Number of rows.
    n::L # Number of columns.
    fillmode::Bool
    buffer::Union{Buffer{L,K,T}, Nothing}
    colmajor::Union{MappedPackedCSC{K,L,T}, Nothing}
    rowmajor::Union{MappedPackedCSC{L,K,T}, Nothing}
end

"""
    dynamicsparse(I, J, V, [m, n])

Creates a dynamic sparse matrix `S` of dimensions `m`×`n` such that `S[I[k], J[k]] = V[k]`.
"""
function dynamicsparse(I::Vector{K}, J::Vector{L}, V::Vector{T}, m = _guess_length(I), n = _guess_length(J)) where {K,L,T}
    return DynamicSparseMatrix(
        m, n, false, nothing, dynamicsparsecolmajor(I,J,V), dynamicsparsecolmajor(J,I,V)
    )
end

"""
    dynamicsparse(Ti, Tj, Tv [; fill_mode = true])

Creates an empty dynamic sparse matrix with row keys of type `Ti`, column keys of 
type `Tj`, and non-zero values of type `Tv`.
By default, the matrix is returned in a "fill mode".
This allows the user to fill the matrix with non-zero entries.
All the write operations are stored in a `Dict`.
When the matrix is filled, the user must call `closefillmode!(matrix)`.
"""
function dynamicsparse(::Type{K}, ::Type{L}, ::Type{T}; fill_mode = true) where {K,L,T}
    return if fill_mode
        DynamicSparseMatrix(
            zero(K), zero(L), true, buffer(K,L,T), nothing, nothing
        )
    else
        DynamicSparseMatrix(
            zero(K), zero(L), false, nothing, dynamicsparsecolmajor(K,L,T), dynamicsparsecolmajor(L,K,T)
        )
    end
end

function Base.setindex!(m::DynamicSparseMatrix{K,L,T}, val, row::K, col::L) where {K,L,T}
    if !iszero(val)
        m.m = max(m.m, row)
        m.n = max(m.n, col)
    end
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
    return m.colmajor[row, col] # TODO : change when row is a colon.
end

function Base.view(m::DynamicSparseMatrix{K,L,T}, row::K, ::Colon) where {K,L,T}
    return m.fillmode ? view(m.buffer, row, :) : view(m.rowmajor, :, row)
end

function Base.view(m::DynamicSparseMatrix{K,L,T}, ::Colon, col::L) where {K,L,T}
    m.fillmode && error("View of a column not available in fill mode.")
    return view(m.colmajor, :, col)
end

Base.ndims(m::DynamicSparseMatrix) = 2
SparseArrays.nnz(m::DynamicSparseMatrix) = nnz(m.rowmajor)
Base.size(m::DynamicSparseMatrix) = (m.m, m.n)
Base.size(m::DynamicSparseMatrix, i) = size(m)[i]

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
            setindex!(matrix, vals[j], row, colids[j])
        end
    end
    return true
end

function closefillmode!(matrix::DynamicSparseMatrix{K,L,T}) where {K,L,T}
    matrix.fillmode || error("Cannot close fill mode because matrix is not in fill mode.")
    I, J, V = get_rowids_colids_vals(matrix.buffer)
    matrix.fillmode = false
    matrix.buffer = nothing
    matrix.colmajor = dynamicsparsecolmajor(I,J,V)
    matrix.rowmajor = dynamicsparsecolmajor(J,I,V)
    return true
end


function Base.show(io::IO, matrix::DynamicSparseMatrix{K,L,T}) where {K,L,T}
    #col major iteration
    pma = matrix.colmajor.pcsc.pma
    semaphores = matrix.colmajor.pcsc.semaphores
    j = 1
    for (index, elmt) in enumerate(pma.array)
        if index in semaphores
            j += 1
            print(io, "\n")
        else
            if !isnothing(elmt)
                (i, value) = elmt
                print(io, " [$(j), $(i)] = $(value) ")
            end
        end 
    end 
end