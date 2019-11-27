function dynsparsevec_instantiation()
    I = [1, 2, 5, 5, 3, 10, 1, 8, 1, 5]
    V = [1.0, 3.5, 2.1, 8.5, 2.1, 1.1, 5.0, 7.8, 1.1, 2.0]

    vec = dynamicsparsevec(I,V)

    @test repr(vec) == "16-element DynamicSparseArrays.PackedMemoryArray{Int64,Float64,DynamicSparseArrays.NoPredictor} with 6 stored entries.\n"

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

    @test ndims(pma) == 1
    @test size(pma) == (length(kv3),)
    @test length(pma) == length(kv3)

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

function dynamicsparsevec_deletions()
    I = [1, 2, 5, 5, 3, 10, 1, 8, 1, 5]
    V = [1.0, 3.5, 2.1, 8.5, 2.1, 1.1, 5.0, 7.8, 1.1, 2.0]

    vec = dynamicsparsevec(I,V)

    @test repr(vec) == "16-element DynamicSparseArrays.PackedMemoryArray{Int64,Float64,DynamicSparseArrays.NoPredictor} with 6 stored entries.\n"

    @test vec[1] == 1.0 + 1.1 + 5.0
    @test vec[2] == 3.5
    @test vec[3] == 2.1
    @test vec[4] == 0.0
    @test vec[5] == 2.1 + 8.5 + 2.0
    @test vec[8] == 7.8
    @test vec[10] == 1.1

    vec[1] = 0
    @test vec[1] == 0

    vec[2] = 0
    @test vec[2] == 0

    vec[3] = 0
    @test vec[3] == 0
    return
end