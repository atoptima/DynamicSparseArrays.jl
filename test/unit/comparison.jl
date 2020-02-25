function test_equal()
    array1 = [nothing, (1,1), nothing, nothing, (2,1), nothing, (3,2)]
    array2 = [nothing, (1,1), (2,1), (3,2), nothing]
    @test DynamicSparseArrays._arrays_equal(array1, array2)

    array1 = [nothing, (1,1), nothing, nothing, (2,1), nothing, (3,2)]
    array2 = [nothing, (1,1), (2,1), (3,2), (4,2)]
    @test DynamicSparseArrays._arrays_equal(array1, array2) == false
end