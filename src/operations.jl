struct Transposed{T}
    array::T
end

Base.transpose(M::DynamicSparseMatrix) = Transposed(M)

function Base.:(*)(M::DynamicSparseMatrix{K,L,T}, v::PackedMemoryArray{L,T}) where {K,L,T}
    return _mult(M.colmajor, v)
end

function Base.:(*)(M::Transposed{DynamicSparseMatrix{K,L,T}}, v::PackedMemoryArray{K,T}) where {K,L,T}
    return _mult(M.array.rowmajor, v)
end

function _mult(M::MappedPackedCSC{K,L,T}, v::PackedMemoryArray{L,T}) where {K,L,T}
    result = Dict{L, T}()

    col_key_pos::Int = 1
    next_col_key_pos::Int = 2

    matrix_row_start::Int = 0
    matrix_row_end::Int = 0
    matrix_row_pos::Int = 0

    for vec_pos in 1:length(v.array)
        entry = v.array[vec_pos]
        if entry !== nothing
            vec_row_id, val = entry
            while col_key_pos <= length(M.col_keys) && M.col_keys[col_key_pos] < vec_row_id
                col_key_pos += 1
            end

            if col_key_pos > length(M.col_keys)
                break
            end

            if M.col_keys[col_key_pos] != vec_row_id
                continue
            end

            next_col_key_pos = col_key_pos + 1
            while next_col_key_pos <= length(M.col_keys) && M.col_keys[next_col_key_pos] === nothing
                next_col_key_pos += 1
            end

            matrix_row_start = M.pcsc.semaphores[col_key_pos] + 1
            matrix_row_end = length(M.pcsc.pma.array)
            if next_col_key_pos <= length(M.col_keys)
                matrix_row_end = M.pcsc.semaphores[next_col_key_pos] - 1
            end

            for matrix_row_pos in matrix_row_start:matrix_row_end
                entry = M.pcsc.pma.array[matrix_row_pos]
                if entry !== nothing
                    matrix_row_id, coeff = entry
                    result[matrix_row_id] = get(result, matrix_row_id, 0.0) + val * coeff
                end
            end
            col_key_pos = next_col_key_pos
        end
    end
    return result
end

