function iterate_dynsparsevec(vector)
    sum = 0.0
    for (key, value) in vector
        @inbounds sum += value
    end
    return sum
end

function iterate_sparsevec(vector)
    sum = 0.0
    for i in eachindex(vector)
        @inbounds sum += vector[i]
    end
    return sum
end

function iterate_matrix(matrix, I, J)
    sum = 0.0
    for k in eachindex(I)
        @inbounds sum += matrix[I[k], J[k]]
    end
    return sum
end

function dynsparsevec_it_perfomance(vector::DynamicSparseVector)
    bench = @benchmark iterate_dynsparsevec($vector)
    elapsed_time = mean(bench).time
    return elapsed_time
end

function sparsevec_it_perfomance(vector::SparseVector)
    bench = @benchmark iterate_sparsevec($vector)
    elapsed_time = mean(bench).time
    return elapsed_time
end

function dynsparsematrix_it_perfomance(matrix::DynamicSparseMatrix, I, J)
    bench = @benchmark iterate_matrix($matrix, $I, $J)
    elapsed_time = mean(bench).time
    return elapsed_time
end

function sparsematrix_it_perfomance(matrix::SparseMatrixCSC, I, J)
    bench = @benchmark iterate_matrix($matrix, $I, $J)
    elapsed_time = mean(bench).time
    return elapsed_time
end

