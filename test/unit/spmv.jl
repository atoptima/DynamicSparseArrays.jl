DynamicSparseArrays.semaphore_key(::Type{Float64}) = 0.0

function test_spmv_1()
    I = [1.0, 1.0, 1.0, 2.0, 2.0, 3.0, 4.0, 4.0, 4.0]
    J = [1, 3, 5, 2, 4, 4, 1, 4, 5]
    V = [1, 2, 1, 2, 1, 3, 3, 2, 2]
    matrix = dynamicsparse(I, J, V)

    I2 = [1, 3, 5]
    V2 = [1, 1, 1]
    vec = dynamicsparsevec(I2, V2)

    result = matrix * vec

    # The multiplication returns a Dict.
    @test result[1.0] == 4
    @test get(result, 2.0, 0.0) == 0.0
    @test get(result, 3.0, 0.0) == 0.0
    @test result[4.0] == 5
    @test get(result, 5.0, 0.0) == 0.0
end


function test_spmv_2()
    I = [1, 1, 1, 2, 2, 3, 4, 4, 4]
    J = [1.0, 3.0, 5.0, 2.0, 4.0, 4.0, 1.0, 4.0, 5.0]
    V = [1, 2, 1, 2, 1, 3, 3, 2, 2]
    matrix = dynamicsparse(I, J, V)

    I2 = [1, 3, 5]
    V2 = [1, 1, 1]
    vec = dynamicsparsevec(I2, V2)

    result = transpose(matrix) * vec

    # The multiplication returns a Dict.
    @test result[1.0] == 1
    @test get(result, 2, 0.0) == 0.0
    @test result[3.0] == 2
    @test result[4.0] == 3
    @test result[5.0] == 1
end

function test_spmv_3()
    I = [1, 1, 3, 3, 4, 4, 4, 6, 6, 6]
    J = [2, 4, 1, 3, 1, 3, 6, 1, 3, 6]
    V = [1, 2, 1, 1, 1, 2, 1, 1, 1, 1]
    matrix = dynamicsparse(I, J, V)

    I2 = [2, 5, 6]
    V2 = [1, 1, 1]
    vec = dynamicsparsevec(I2, V2)

    @show vec

    result = matrix * vec

    @show result

    @test result[1] == 1
    @test get(result, 2, 0.0) == 0.0
    @test get(result, 3, 0.0) == 0.0
    @test result[4] == 1
    @test get(result, 5, 0.0) == 0.0
    @test result[6] == 1
end

function test_spmv()
    test_spmv_1()
    test_spmv_2()
    test_spmv_3()
end