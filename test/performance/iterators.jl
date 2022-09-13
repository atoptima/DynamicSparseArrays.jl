function iterate_dynsparsevec(vector)
    sum = 0.0
    for e in vector
        @inbounds sum += last(e)
    end
    return sum
end

function iterate_sparsevec(vector)
    sum = 0.0
    for e in vector
        @inbounds sum += e
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

