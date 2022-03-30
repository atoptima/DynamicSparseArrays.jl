DynamicSparseArrays.semaphore_key(::Type{Float64}) = 0.0

# Classic test for sparse matrix sparse vector multiplication
function test_spmv_1()
    I = ['a', 'a', 'a', 'b', 'b', 'c', 'd', 'd', 'd']
    J = [1, 3, 5, 2, 4, 4, 1, 4, 5]
    V = [1, 2, 1, 2, 1, 3, 3, 2, 2]
    matrix = dynamicsparse(I, J, V)
    @show typeof(matrix)

    I2 = [1, 3, 5]
    V2 = [1, 1, 1]
    vec = dynamicsparsevec(I2, V2)

    result = matrix * vec

    # The multiplication returns a Dict.
    @test result['a'] == 4
    @test get(result, 'b', 0.0) == 0.0
    @test get(result, 'c', 0.0) == 0.0
    @test result['d'] == 5
    @test get(result, 'e', 0.0) == 0.0
    return
end

# Test with for transposed sparse matrix sparse vector multiplication
function test_spmv_2()
    I = ['a', 'a', 'a', 'b', 'b', 'c', 'd', 'd', 'd']
    J = [1, 3, 5, 2, 4, 4, 1, 4, 5]
    V = [1, 2, 1, 2, 1, 3, 3, 2, 2]
    matrix = dynamicsparse(I, J, V)

    I2 = ['a', 'c', 'e']
    V2 = [1, 1, 1]
    vec = dynamicsparsevec(I2, V2)

    transposed_matrix = transpose(matrix)
    for (i,j,v) in Iterators.zip(I,J,V)
        @test transposed_matrix[j,i] == matrix[i,j] == v
    end

    result = transpose(matrix) * vec

    # The multiplication returns a Dict.
    @test result[1] == 1
    @test get(result, 2, 0.0) == 0.0
    @test result[3] == 2
    @test result[4] == 3
    @test result[5] == 1


    transposed_matrix[2, 'e'] = 5
    @test transposed_matrix[2, 'e'] == matrix['e', 2] == 5
    return
end

# Test with empty columns and rows in the matrix
function test_spmv_3()
    I = [1, 1, 3, 3, 4, 4, 4, 6, 6, 6]
    J = [2, 4, 1, 3, 1, 3, 6, 1, 3, 6]
    V = [1, 2, 1, 1, 1, 2, 1, 1, 1, 1]
    matrix = dynamicsparse(I, J, V)

    I2 = [2, 5, 6]
    V2 = [1, 1, 1]
    vec = dynamicsparsevec(I2, V2)

    result = matrix * vec

    @test result[1] == 1
    @test get(result, 2, 0.0) == 0.0
    @test get(result, 3, 0.0) == 0.0
    @test result[4] == 1
    @test get(result, 5, 0.0) == 0.0
    @test result[6] == 1
    return
end

# Test with non continugous keys in the matrix (column removal)
function test_spmv_4()
    I = [1, 1, 3, 3, 4, 4, 4, 6, 6, 6]
    J = [2, 4, 1, 3, 1, 3, 6, 1, 3, 6]
    V = [1, 2, 1, 1, 1, 1, 1, 1, 1, 1]
    matrix = dynamicsparse(I, J, V)

    I2 = [2, 3, 5, 6]
    V2 = [1, 1, 1, 1]
    vec = dynamicsparsevec(I2, V2)

    result = matrix * vec

    @test get(result, 1, 0.0) == 1
    @test get(result, 2, 0.0) == 0
    @test get(result, 3, 0.0) == 1
    @test get(result, 4, 0.0) == 2
    @test get(result, 5, 0.0) == 0
    @test get(result, 6, 0.0) == 2

    deletecolumn!(matrix, 3)

    result = matrix * vec

    @test get(result, 1, 0.0) == 1
    @test get(result, 2, 0.0) == 0
    @test get(result, 3, 0.0) == 0
    @test get(result, 4, 0.0) == 1
    @test get(result, 5, 0.0) == 0
    @test get(result, 6, 0.0) == 1

    deleterow!(matrix, 4)

    result = matrix * vec

    @test get(result, 1, 0.0) == 1
    @test get(result, 2, 0.0) == 0
    @test get(result, 3, 0.0) == 0
    @test get(result, 4, 0.0) == 0
    @test get(result, 5, 0.0) == 0
    @test get(result, 6, 0.0) == 1
    return
end

function test_spmv()
    test_spmv_1()
    test_spmv_2()
    test_spmv_3()
    test_spmv_4()
end