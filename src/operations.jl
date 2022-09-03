struct Transposed{T}
    array::T
end

Base.transpose(mat::DynamicSparseMatrix) = Transposed(mat)
Base.setindex!(mat::Transposed, val, row, col) = setindex!(mat.array, val, col, row)
Base.getindex(mat::Transposed, row, col) = getindex(mat.array, col, row)
Base.size(mat::Transposed) = reverse(size(mat.array))
Base.size(mat::Transposed, i) = size(mat)[i]

_mul_output(result::Dict{K,V}, _) where {K,V} = result
_mul_output(result::Dict{K,V}, n::K) where {K<:Integer,V} = sparsevec(result, n)

Base.:(*)(mat::DynamicSparseMatrix{K,L,T}, v::DynamicSparseVector{L,T}) where {K,L,T} = 
    _mul_output(_mul(mat.colmajor, v.pma), size(mat, 1))

Base.:(*)(mat::DynamicSparseMatrix{K,L,T}, v::SparseVector{T,L}) where {K,L,T} =
    _mul_output(_mul(mat.colmajor, v), size(mat, 1))

Base.:(*)(mat::Transposed{DynamicSparseMatrix{K,L,T}}, v::DynamicSparseVector{K,T}) where {K,L,T} = 
    _mul_output(_mul(mat.array.rowmajor, v.pma), size(mat, 1))

Base.:(*)(mat::Transposed{DynamicSparseMatrix{K,L,T}}, v::SparseVector{T,K}) where {K,L,T} =
    _mul_output(_mul(mat.array.rowmajor, v), size(mat, 1))

Base.:(*)(v::DynamicSparseVector{L,T}, mat::Transposed{DynamicSparseMatrix{K,L,T}}) where {K,L,T} = 
    _mul_output(_mul(mat.array.colmajor, v.pma), size(mat, 2))

Base.:(*)(v::SparseVector{T,L}, mat::Transposed{DynamicSparseMatrix{K,L,T}}) where {K,L,T} =
    _mul_output(_mul(mat.array.colmajor, v), size(mat, 2))

Base.:(*)(v::DynamicSparseVector{K,T}, mat::DynamicSparseMatrix{K,L,T}) where {K,L,T} = 
    _mul_output(_mul(mat.rowmajor, v.pma), size(mat, 2))

Base.:(*)(v::SparseVector{T,K}, mat::DynamicSparseMatrix{K,L,T}) where {K,L,T} =
    _mul_output(_mul(mat.rowmajor, v), size(mat, 2))

function _mul_dyn_mat_col_loop!(result, mat, col_key_pos, vec_row_id, vec_val)
    while col_key_pos <= length(mat.col_keys) && mat.col_keys[col_key_pos] < vec_row_id
        col_key_pos += 1
    end

    if col_key_pos > length(mat.col_keys)
        return true, col_key_pos # finished to explore the mat, we stop the spMv
    end

    if mat.col_keys[col_key_pos] != vec_row_id
        return false, col_key_pos # no non-zero value in this column, we move to next one.
    end

    next_col_key_pos = col_key_pos + 1
    while next_col_key_pos <= length(mat.col_keys) && isnothing(mat.col_keys[next_col_key_pos])
        next_col_key_pos += 1
    end

    mat_row_start = mat.pcsc.semaphores[col_key_pos] + 1
    mat_row_end = length(mat.pcsc.pma.array)
    if next_col_key_pos <= length(mat.col_keys)
        mat_row_end = mat.pcsc.semaphores[next_col_key_pos] - 1
    end

    for mat_row_pos in mat_row_start:mat_row_end
        mat_entry = mat.pcsc.pma.array[mat_row_pos]
        if !isnothing(mat_entry)
            mat_row_id, coeff = mat_entry
            result[mat_row_id] = get(result, mat_row_id, 0.0) + vec_val * coeff
        end
    end
    return false, next_col_key_pos
end

function _mul(mat::MappedPackedCSC{K,L,T}, vec::SparseVector{T,L}) where {K,L,T}
    result = Dict{K,T}()
    col_key_pos = 1
    @inbounds begin
        for vec_row_id in rowvals(vec)
            vec_val = vec[vec_row_id]
            stop, col_key_pos = _mul_dyn_mat_col_loop!(result, mat, col_key_pos, vec_row_id, vec_val)
            stop && break
        end
    end
    return result
end

function _mul(mat::MappedPackedCSC{K,L,T}, v::PackedMemoryArray{L,T}) where {K,L,T}
    result = Dict{K,T}()
    col_key_pos = 1

    @inbounds begin
        for vec_pos in eachindex(v.array)
            vec_entry = v.array[vec_pos]
            if !isnothing(vec_entry)
                vec_row_id, vec_val = vec_entry
                stop, col_key_pos = _mul_dyn_mat_col_loop!(result, mat, col_key_pos, vec_row_id, vec_val)
                stop && break
            end
        end
    end
    return result
end

