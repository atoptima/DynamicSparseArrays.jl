struct Transposed{T}
    array::T
end

Base.transpose(matrix::DynamicSparseMatrix) = Transposed(matrix)

function Base.:(*)(matrix::DynamicSparseMatrix{K,L,T}, v::PackedMemoryArray{L,T}) where {K,L,T}
    return _mult(matrix.colmajor, v)
end

function Base.:(*)(matrix::Transposed{DynamicSparseMatrix{K,L,T}}, v::PackedMemoryArray{K,T}) where {K,L,T}
    return _mult(matrix.array.rowmajor, v)
end

function _mult(matrix::MappedPackedCSC{K,L,T}, v::PackedMemoryArray{L,T}) where {K,L,T}
    result = Dict{K,T}()

    col_key_pos::Int = 1
    next_col_key_pos::Int = 2

    matrix_row_start::Int = 0
    matrix_row_end::Int = 0
    matrix_row_pos::Int = 0

    for vec_pos in 1:length(v.array)
        entry = v.array[vec_pos]
        if entry !== nothing
            vec_row_id, val = entry
            while col_key_pos <= length(matrix.col_keys) && matrix.col_keys[col_key_pos] < vec_row_id
                col_key_pos += 1
            end

            if col_key_pos > length(matrix.col_keys)
                break
            end

            if matrix.col_keys[col_key_pos] != vec_row_id
                continue
            end

            next_col_key_pos = col_key_pos + 1
            while next_col_key_pos <= length(matrix.col_keys) && matrix.col_keys[next_col_key_pos] === nothing
                next_col_key_pos += 1
            end

            matrix_row_start = matrix.pcsc.semaphores[col_key_pos] + 1
            matrix_row_end = length(matrix.pcsc.pma.array)
            if next_col_key_pos <= length(matrix.col_keys)
                matrix_row_end = matrix.pcsc.semaphores[next_col_key_pos] - 1
            end

            for matrix_row_pos in matrix_row_start:matrix_row_end
                entry = matrix.pcsc.pma.array[matrix_row_pos]
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

