function dynsparsearray_spmv_performance(matrix::DynamicSparseMatrix, vector::DynamicSparseVector)
    bench = @benchmark begin
        result = $matrix * $vector
    end
    println("dynsparsearray_spmv_performance")
    elapsed_time = mean(bench).time
    return elapsed_time
end

function sparsearray_spmv_performance(matrix::SparseMatrixCSC, vector::SparseVector)
    bench = @benchmark begin
        result = $matrix * $vector
    end
    elapsed_time = mean(bench).time
    return elapsed_time
end
