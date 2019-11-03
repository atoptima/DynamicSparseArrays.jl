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

function create_partitioned_array(capacity::Int, expnbempty::Int)
    nbempty = 0
    array =  Vector{Union{Tuple{Int,Int}, Nothing}}(nothing, capacity)
    semaphores = Vector{Int}()
    i = 1
    k = 1
    for j in 1:capacity
        p = rand(rng, 0:0.001:1)
        if p < expnbempty/capacity
            array[j] = nothing
            nbempty += 1
        else
            if p > 0.95
                array[j] = (0, k)
                push!(semaphores, j)
                i = 1
                k += 1
            else
                val = rand(1:150)
                array[j] = (i, val)
                i += 1
            end
        end
    end
    return array, semaphores, nbempty, capacity - nbempty
end

function test_rebalance_with_semaphores(capacity::Int, expnbempty::Int)
    array, sem, nbempty, nbcells = create_partitioned_array(capacity, expnbempty)

    for pos in sem
        @test array[pos][1] == 0
    end

    DynamicSparseArrays._pack!(array, 1, length(array), nbcells)
    # for i in 1:nbcells
    #     @test array[i][1] == i
    # end

    DynamicSparseArrays._spread!(array, 1, length(array), nbcells, sem)
    c = 0
    i = 1
    for j in 1:capacity
        if array[j] == nothing
            c += 1
        else
            (key, val) = array[j]
            if key != 0
                @test key == i
                i += 1
            else 
                i = 1
            end
        end
    end
    @test nbempty == c

    for pos in sem
        @test array[pos][1] == 0
    end
    return
end