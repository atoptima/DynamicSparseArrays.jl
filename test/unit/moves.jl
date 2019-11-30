function test_movecellstoleft()
    array, nbempty, _ = array_factory(20, 4, 3)

    # Test 1 : normal use
    array1 = Vector(array)
    to = findfirst(e -> e == nothing, array1)
    from = to + 4
    DynamicSparseArrays._movecellstoleft!(array1, from, to, nothing)
    @test array[to] == nothing
    @test array1[from] == nothing
    @test array[to+1:from] == array1[to:from-1]
    @test array[from+1:end] == array1[from+1:end]

    # Test 2 : try to move on a non-empty cell, error expected
    array2 = Vector(array)
    to = findfirst(e -> e != nothing, array2)
    from = to + 4
    @test_throws ArgumentError DynamicSparseArrays._movecellstoleft!(array2, from, to, nothing)
    @test array == array2

    # Test 3 : from < to, the array does not change
    array3 = Vector(array)
    to = findlast(e -> e == nothing, array3)
    from = to - 2
    DynamicSparseArrays._movecellstoleft!(array3, from, to, nothing)
    @test array == array3

    # Test 4 : Bounds error
    array4 = Vector(array)
    @test_throws BoundsError DynamicSparseArrays._movecellstoleft!(array4, -1, 100, nothing)
    @test_throws BoundsError DynamicSparseArrays._movecellstoleft!(array4, 1, 100, nothing)
    return
end

function test_movecellstoleft_with_semaphores()
    array, semaphores, _, _ = partitioned_array_factory(50, 20, 0.2)
    check_semaphores(array, semaphores)

    # Test 1 : normal use
    array1 = Vector(array)
    semaphores1 = Vector(semaphores)
    to = findfirst(e -> e == nothing, array1)
    from = to + 25 # we move almost all elements of the array to move some semaphores 
    DynamicSparseArrays._movecellstoleft!(array1, from, to, semaphores1)
    check_semaphores(array1, semaphores1)
    @test array[to] == nothing
    @test array1[from] == nothing
    @test array[to+1:from] == array1[to:from-1]
    return
end

function test_movecellstoright()
    array, nbempty, _ = array_factory(20, 4, 3)

    # Test 1 : normal use
    array1 = Vector(array)
    to = findlast(e -> e == nothing, array1)
    from = to - 4
    DynamicSparseArrays._movecellstoright!(array1, from, to, nothing)
    @test array[to] == nothing
    @test array1[from] == nothing
    @test array[from:to-1] == array1[from+1:to]
    @test array[1:from-1] == array1[1:from-1]

    # Test 2 : try to move on empty-cell, error excepted
    array2 = Vector(array)
    to = findlast(e -> e != nothing, array2)
    from = to - 4
    @test_throws ArgumentError DynamicSparseArrays._movecellstoright!(array2, from, to, nothing)
    @test array == array2

    # Test 3 : from > to, the array does not change
    array3 = Vector(array)
    to = findfirst(e -> e == nothing, array3)
    from = to + 2
    DynamicSparseArrays._movecellstoright!(array3, from, to, nothing)
    @test array == array3

    # Test 4 : bounds error
    array4 = Vector(array)
    @test_throws BoundsError DynamicSparseArrays._movecellstoright!(array4, -1, 100, nothing)
    @test_throws BoundsError DynamicSparseArrays._movecellstoright!(array4, 1, 100, nothing)
    return
end

function test_movecellstoright_with_semaphores()
    array, semaphores, _, _ = partitioned_array_factory(50, 20, 0.2)
    check_semaphores(array, semaphores)

    # Test 1 : normal use
    array1 = Vector(array)
    semaphores1 = Vector(semaphores)
    to = findlast(e -> e == nothing, array1)
    from = to - 25 # we move almost all elements of the array to move some semaphores
    DynamicSparseArrays._movecellstoright!(array1, from, to, semaphores1)
    check_semaphores(array1, semaphores1)
    @test array[to] == nothing
    @test array1[from] == nothing
    @test array[from:to-1] == array1[from+1:to]
    @test array[1:from-1] == array1[1:from-1]
    return
end

function test_pack_spread(capacity::Int, expnbempty::Int)
    array, nbempty, nbcells = array_factory(capacity, expnbempty, 1)
    DynamicSparseArrays.pack!(array, 1, length(array), nbcells)
    for i in 1:nbcells
        @test array[i][1] == i
    end

    DynamicSparseArrays.spread!(array, 1, length(array), nbcells)
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

function test_pack_spread_of_empty_array()
    array = Vector{Union{Nothing, Tuple{Int,Float64}}}(nothing, 20)
    @test DynamicSparseArrays.pack!(array, 1, length(array), 0) === nothing
    @test DynamicSparseArrays.spread!(array, 1, length(array), 0, nothing) === nothing
    return
end

function test_pack_spread_with_semaphores(capacity::Int, expnbempty::Int)
    array, sem, nbempty, nbcells = partitioned_array_factory(capacity, expnbempty)

    for pos in sem
        @test array[pos][1] == 0
    end

    DynamicSparseArrays.pack!(array, 1, length(array), nbcells)
    DynamicSparseArrays.spread!(array, 1, length(array), nbcells, sem)
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
