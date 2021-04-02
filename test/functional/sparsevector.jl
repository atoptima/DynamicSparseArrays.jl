function dynsparsevec_simple_use()
    # Test 0 : Create an empty vector
    vec = dynamicsparsevec(Int[], Float64[])
    @test length(vec) == 0

    # Test 1 : instantiate a dynamic sparse vector
    I = [1, 2, 5, 5, 3, 10, 1, 8, 1, 5]
    V = [1.0, 3.5, 2.1, 8.5, 2.1, 1.1, 5.0, 7.8, 1.1, 2.0]

    vec = dynamicsparsevec(I,V)

    @test_skip repr(vec) == "16-element PackedMemoryArray{Int64,Float64,DynamicSparseArrays.NoPredictor} with 6 stored entries.\n"

    @test vec[1] == 1.0 + 1.1 + 5.0
    @test vec[2] == 3.5
    @test vec[3] == 2.1
    @test vec[4] == 0.0
    @test vec[5] == 2.1 + 8.5 + 2.0
    @test vec[8] == 7.8
    @test vec[10] == 1.1

    vec2 = dynamicsparsevec(I,V,*)
    @test vec2[1] == 1.0 * 1.1 * 5.0
    @test vec2[2] == 3.5
    @test vec2[3] == 2.1
    @test vec2[5] == 2.1 * 8.5 * 2.0
    @test vec2[6] == 0.0
    @test vec2[8] == 7.8
    @test vec2[10] == 1.1

    @test ndims(vec) == 1
    @test length(vec) == 6 # (because index 4 is a zero-element)
    @test size(vec)[1] >= length(vec)

    # Test 2 : set some values
    vec[1] = 0 # delete
    vec[2] = 0 # delete
    vec[3] = 0 # delete
    vec[22] = 0 # do nothing
    vec[1001] = 1.8 # new
    vec[987] = 4.7 # new
    vec[2] = 15/3 # new
    vec[4] = 42 # set

    @test vec[1] == 0
    @test vec[2] == 15/3
    @test vec[3] == 0
    @test vec[4] == 42
    @test vec[1001] == 1.8
    @test vec[987] == 4.7

    # Test 3 : iterations
    expected_loop = [(2,5), (4,42), (5,12.6), (8,7.8), (10,1.1), (987,4.7), (1001,1.8)]
    for (i, (key, val)) in enumerate(vec)
        @test (key, val) == expected_loop[i]
    end
    @test length(vec) == length(expected_loop)
    @test size(vec)[1] >= length(vec)

    # Test 4 : SemiColon
    @test vec[:] === vec

    # Test 5 : Equality comparison
    I = [1, 2, 3, 5, 6, 8, 9]
    J = [1.0, 1.0, 1.0, 2.0, 1.0, 1.0, 3.0]
    vec1 = dynamicsparsevec(I,J)

    K = [1, 2, 3, 5, 6, 8, 9, 10, 11]
    L = [1.0, 1.0, 1.0, 2.0, 1.0, 1.0, 3.0, 2.0, 3.0]
    vec2 = dynamicsparsevec(K,L)
    @test vec1 != vec2

    vec2[10] = 0
    vec2[11] = 0
    @test vec1 == vec2
    return
end

function filter_pma()
    pma = PackedMemoryArray(Vector([(1,2.0), (2,3.0),(3,4.0)]))
    even_ids(n) = n[1] % 2 == 0

    @test filter(even_ids, pma) == PackedMemoryArray(Vector([(2,3.0)]))
end

function fill(vec, kv)
    n = 0
    for (k, v) in kv
        vec[k] = v
        n += 1
        @test vec.nb_elements == n
    end
    return
end

function empty(vec, kv)
    n = length(kv)
    for (k, v) in kv
        vec[k] = 0.0
        n -= 1
        @test vec.nb_elements == n
    end
    return
end

function dynsparsevec_fill_empty()
    # Start with an empty sparse vector
    vec = dynamicsparsevec(Int[], Float64[])
    for n in [20, 100, 1000, 10000, 100000]
        kv = Dict{Int, Float64}(
            rand(rng, 1:10000000000) => rand(rng, 1:0.1:10000) for i in 1:n
        )
        fill(vec, kv)
        empty(vec, kv)
    end
    return
end

function dynsparsevec_insertions_and_gets()
    kv1 = Dict{Int, Float64}(
        rand(rng, 1:10000000000) => rand(rng, 1:0.1:10000) for i in 1:1000000
    )
    I = collect(keys(kv1))
    V = collect(values(kv1))
    pma = dynamicsparsevec(I,V)
    for (k,v) in kv1
        @test pma[k] == v
    end

    # insert 1000000 more elements
    kv2 = Dict{Int, Float64}(
        rand(rng, 1:10000000000) => rand(rng, 1:0.1:10000) for i in 1:1000000
    )
    for (k,v) in kv2
        pma[k] = v
    end
    kv3 = merge(kv1, kv2)
    for (k,v) in kv3
        @test pma[k] == v
    end

    #@test ndims(pma) == 1
    #@test size(pma) == (length(kv3),)
    #@test length(pma) == length(kv3)

    kv4 = Dict{Int, Float64}(
        rand(rng, 1:100000) => rand(rng, 1:0.1:10000) for i in 1:10
    )
    I = collect(keys(kv4))
    V = collect(values(kv4))
    pma = dynamicsparsevec(I,V)
    for i in 1:100000
        pma[i] = 10.0
    end
    for i in 1:100000
        @test pma[i] == 10
    end
    return
end
