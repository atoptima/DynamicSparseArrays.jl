using DynamicSparseArrays, Test, Random

rng = MersenneTwister(1234123);

function pma_insertions()
    kv1 = Dict{Int, Float64}(
        rand(rng, 1:10000000000) => rand(rng, 1:0.1:10000) for i in 1:1000000
    )
    keys_array = collect(keys(kv1))
    values_array = collect(values(kv1))
    pma = PackedMemoryArray(keys_array, values_array)
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

function main()
    @testset "Insertions" begin
        pma_insertions()
    end
    return
end

main()