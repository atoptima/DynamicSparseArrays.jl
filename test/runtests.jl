using DynamicSparseArrays, Test, Random

rng = MersenneTwister(1234123);

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


function dynsparsevec_insertions()
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
    return
end

function dynsparsematrix_instantiation()
    I = [1, 4, 3, 5]
    J = [4, 7, 18, 9]
    V = [1, 2, -5, 3]
    matrix = dynamicsparse(I,J,V)
    @test matrix[1,4] == 1
    @test matrix[4,7] == 2
    @test matrix[3,18] == -5
    @test matrix[5,9] == 3

    I = [1, 1, 4, 3, 5, 1, 3, 1, 4]
    J = [4, 3, 7, 18, 9, 3, 18, 4, 7]
    V = [1, 8, 2, -5, 3, 2, 1, 1, 2]
    matrix = dynamicsparse(I,J,V)
    @test matrix[1,4] == 1 + 1
    @test matrix[1,3] == 8 + 2
    @test matrix[4,7] == 2 + 2
    @test matrix[3,18] == -5 + 1
    @test matrix[5,9] == 3
    return
end

function pma()
    @testset "Instantiation (with multiple elements)" begin
        dynsparsevec_instantiation()
    end
    @testset "Insertions" begin
        dynsparsevec_insertions()
    end
    return
end

function pcsr()
    @testset "Instantiation (with multiple elements)" begin
        dynsparsematrix_instantiation()
    end
end

pma()
pcsr()