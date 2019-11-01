function create_array(capacity::Int, expnbempty::Int)
    nbempty = 0
    array =  Vector{Union{Tuple{Int,Int}, Nothing}}(nothing, capacity)
    i = 1
    for j in 1:capacity
        p = rand(rng, 0:0.001:1)
        if p < expnbempty/capacity
            array[j] = nothing
            nbempty += 1
        else
            val = rand(1:150)
            array[j] = (i, val)
            i += 1
        end
    end
    return array, nbempty, i - 1
end

function test_rebalance(capacity::Int, expnbempty::Int)
    array, nbempty, nbcells = create_array(capacity, expnbempty)
    DynamicSparseArrays._pack!(array, 1, length(array), nbcells)
    for i in 1:nbcells
        @test array[i][1] == i
    end

    DynamicSparseArrays._spread!(array, 1, length(array), nbcells)
    c = 0
    i = 1
    for j in 1:capacity
        if array[j] == nothing
            c += 1
        else
            (key, val) = array[j]
            @test key == i
            i += 1
        end
    end
    @test nbempty == c
    return
end