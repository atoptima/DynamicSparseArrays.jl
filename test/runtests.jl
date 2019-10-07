using DynamicSparseArrays

function main()
    pma = PackedMemoryArray{Int,Float64}(100)
    @show pma.capacity
    @show pma.segment_capacity
    @show pma.nb_segments
    @show pma.height


    @show DynamicSparseArrays._find(pma, 2)
    @show DynamicSparseArrays._insert(pma, 2, 1.5)
    @show DynamicSparseArrays._find(pma, 2)
    return
end

main()