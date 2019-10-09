using DynamicSparseArrays, Test

function main()
    pma = PackedMemoryArray{Int,Float64}(100)
    @show pma.capacity
    @show pma.segment_capacity
    @show pma.nb_segments
    @show pma.height

    @test pma[2] == 0
    pma[2] = 1.5
    @show pma[2]
    @test pma[2] == 1.5
    pma[2] = 2
    @show pma[2]
    @test pma[2] == 2
    @show pma[3] = 6
    @show pma[9] = 18
    @show pma[6] = 2.0
    @show pma[4] = 10.0
    return
end

main()