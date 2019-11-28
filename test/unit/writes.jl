function test_insert()
    # No need to test with semaphores

    # Test A : insertion in array
    array = [(2, 10), nothing, (3, 10), (5, 10), (6, 10), nothing, (7, 10)]

    # Test A.1 : try to insert key 4 and value 10
    DynamicSparseArrays.insert!(array, 4, 10, nothing)
    @test array == [(2, 10), nothing, (3, 10), (4, 10), (5, 10), (6, 10), (7, 10)]

    # Test A.2 : try to insert key 1 and value 10
    DynamicSparseArrays.insert!(array, 1, 10, nothing)
    @test array == [(1, 10), (2, 10), (3, 10), (4, 10), (5, 10), (6, 10), (7, 10)]

    # Test A.3, try to insert key 2 and value 11, but key 2 exists
    DynamicSparseArrays.insert!(array, 2, 11, nothing)
    @test array == [(1, 10), (2, 11), (3, 10), (4, 10), (5, 10), (6, 10), (7, 10)]

    # Test A.4 : try to insert key 8 and value 10 in a full array, should catch an ErrorException
    @test_throws ErrorException DynamicSparseArrays.insert!(array, 8, 10, nothing)

    # Test B : insertion in a subarray starting at pos 3 and finishing at pos 6
    array = [(2, 10), nothing, nothing, (3, 10), (5, 10), (6, 10), nothing, (7, 10)]
    #                          |------------ subarray ----------|

    # Test B.1 : try to insert key 1 and value 10 in subarray
    DynamicSparseArrays.insert!(array, 1, 10, 3, 6, nothing)
    @test array == [(2, 10), (1, 10), nothing, (3, 10), (5, 10), (6, 10), nothing, (7, 10)]
    #                                |------------ subarray ------------|

    # Test B.2 : try to insert key 1 and value 11 in subarray
    DynamicSparseArrays.insert!(array, 1, 11, 3, 6, nothing)
    @test array == [(2, 10), (1, 10), (1, 11), (3, 10), (5, 10), (6, 10), nothing, (7, 10)]
    #                                 |------------ subarray ----------|

    # Test B.3 : try to insert key 4 and value 10 in subarray
    DynamicSparseArrays.insert!(array, 4, 10, 3, 6, nothing)
    @test array == [(2, 10), (1, 10), (1, 11), (3, 10), (4,10), (5, 10), (6, 10), (7, 10)]
    #                                 |----------- subarray ----------|
    return
end

function test_delete()
    # No need to test with semaphores and subarrays
    array = [(2, 10), (3, 10), nothing, (8, 10), (9, 10), nothing, (10, 10)]

    # Test 1 : delete element with key 2
    output = DynamicSparseArrays.delete!(array, 2)
    @test array == [nothing, (3, 10), nothing, (8, 10), (9, 10), nothing, (10, 10)]
    @test output == (1, true)

    # Test 2 : delete element with key 2 (already deleted)
    output = DynamicSparseArrays.delete!(array, 2)
    @test array == [nothing, (3, 10), nothing, (8, 10), (9, 10), nothing, (10, 10)]
    @test output == (0, false) 

    # Test 3 : purge from pos 3 to pos 5
    output = DynamicSparseArrays.purge!(array, 3, 5)
    @test array == [nothing, (3, 10), nothing, nothing, nothing, nothing, (10, 10)]
    @test output == (4, true)
    return
end