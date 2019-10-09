using DynamicSparseArrays, Test, BenchmarkTools

function test_insert_benchmark()
    st = Dict{Int, Float64}()
    pma = PackedMemoryArray{Int,Float64}(10)
    for i in 1:30
        k = rand(1:1000000)
        v = rand(1:0.001:10000)
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

function main()
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

    @btime test_insert_benchmark()

    return
end

main()