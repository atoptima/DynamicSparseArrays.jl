using DynamicSparseArrays, Test, BenchmarkTools, Random

rng = MersenneTwister(1234123);

function test_insert_benchmark()
    st = Dict{Int, Float64}()
    pma = PackedMemoryArray{Int,Float64}(10)
    for i in 1:30
        k = rand(rng, 1:1000000)
        v = rand(rng, 1:0.001:10000)
        pma[k] = v
        st[k] = v
    end
    @show pma.capacity
    pos = 1
    for (k,v) in st
        @show pos
        @test v == pma[k]
        pos += 1
    end
    return
end

function create(keys_array, values_array)
    pma = PackedMemoryArray(keys_array, values_array)
    # for (i, k) in enumerate(keys_array)
    #     @test pma[k] == values_array[i]
    # end
    return pma
end

function insert(pma, dict)
    for (k,v) in dict
        pma[k] = v
    end
end

function main()
    #some_test_to_improve()
    pma = PackedMemoryArray{Int,Float64}(100)
    @show pma.capacity
    @show pma.segment_capacity
    @show pma.nb_segments
    @show pma.height

    # @test pma[2] == 0
    # pma[2] = 1.5
    # @show pma[2]
    # @test pma[2] == 1.5
    # pma[2] = 2
    # @show pma[2]
    # @test pma[2] == 2
    # @show pma[3] = 6
    # @show pma[9] = 18
    # @show pma[6] = 2.0
    # @show pma[4] = 10.0


    kv = Dict{Int, Float64}(rand(rng, 1:10000000000) => rand(rng, 1:0.1:10000) for i in 1:1000000)
    keys_array = collect(keys(kv))
    values_array = collect(values(kv))
    @time begin
        pma = create(keys_array, values_array)
    end
    for (k,v) in kv
        if pma[k] != v
            println("k = $k, v =$v, pma[k] = $(pma[k])")
            error("failed")
        end
    end

    kv = Dict{Int, Float64}(rand(rng, 1:10000000000) => rand(rng, 1:0.1:10000) for i in 1:10000)
    keys_array = collect(keys(kv))
    values_array = collect(values(kv))
    pma = PackedMemoryArray(keys_array, values_array)

    k = 1
    while k <= 500000
        println("insert $k element")
        kv = Dict{Int, Float64}(rand(rng, 1:10000000000) => rand(rng, 1:0.1:10000) for i in 1:k)
        @time begin 
            insert(pma, kv)
        end
        k *= 10
    end


    # for (k,v) in kv
    #     if pma[k] != v
    #         println("k = $k, v =$v, pma[k] = $(pma[k])")
    #         error("failed")
    #     end
    # end

    #@btime test_insert_benchmark()


    return
end

main()