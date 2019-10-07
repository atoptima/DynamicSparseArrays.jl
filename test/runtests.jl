using DynamicSparseArrays

function main()
    pma = PackedMemoryArray{Float64}(100)
    @show pma.capacity
    @show pma.segment_capacity
    @show pma.nb_segments
    @show pma.height
    return
end

main()