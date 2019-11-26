function test_movecellstoleft()
    array, nbempty, nbcells = array_factory(20, 4)

    # Test 1 : normal use
    array1 = Vector(array)
    to = findfirst(e -> e == nothing, array1)
    from = to + 4
    DynamicSparseArrays._movecellstoleft!(array1, from, to, nothing)
    @test array[to] == nothing
    @test array[to+1:from] == array1[to:from-1]
    @test array1[from] == nothing
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
end

function test_movecellstoright()
    array, nbempty, nbcells = array_factory(20, 4)

    # Test 1 : normal use
    array1 = Vector(array)
    to = findlast(e -> e == nothing, array1)
    from = to - 4
    DynamicSparseArrays._movecellstoright!(array1, from, to, nothing)
    @test array[to] == nothing
    @test array[from:to-1] == array1[from+1:to]
    @test array1[from] == nothing
    @test array[1:from-1] == array1[1:from-1]

    # Test 2 : try to move on empty-cell, error excepted
    array2 = Vector(array)
    to = findlast(e -> e != nothing, array2)
    from = to - 4
    @test_throws ArgumentError DynamicSparseArrays._movecellstoleft!(array2, from, to, nothing)
    @test array == array2

    # Test 3 : from > to, the array does not change
    array3 = Vector(array)
    to = findfirst(e -> e == nothing, array3)
    from = to + 2
    DynamicSparseArrays._movecellstoright!(array3, from, to, nothing)
    @test array == array3
end

