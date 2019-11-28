function test_find()
    # Test 1 : look for keys in the entire array

    array = [nothing, (3, 10), (4, 10), nothing, (8, 10), nothing, (9, 10)]

    # Find key 1 : does not exist, no predecessor, should have (0, nothing)
    # Find key 2 : same
    # Find key 3 : exists at position 2, should have (2, (3, 10))
    # Find key 4 : exists at position 3, should have (3, (4, 10))
    # Find key 5 : does not exist, key 4 is predecessor, should have (3, (4, 10))
    # Find key 7 : same
    # Find key 8 : exists at position 5, should have (5, (8, 10))
    # Find key 9 : exists at position 7, should have (7, (9, 10))
    # Find key 100 : does not exist, key 9 is predecessor, should have (7, (9, 10))

    look_for_key = [1, 2, 3, 4, 5, 7, 8, 9, 100]
    expected_output = [(0, nothing), (0, nothing), (2, (3, 10)), (3, (4, 10)), (3, (4, 10)), (3, (4, 10)), (5, (8, 10)), (7, (9, 10)), (7, (9, 10))]

    for i in 1:9
        output = DynamicSparseArrays.find(array, look_for_key[i])
        @test output == expected_output[i]
    end


    # Test 2 : look for keys in the subarray starting at pos 4 & finishing at pos 6

    # [ nothing, (3, 10), (4, 10),  nothing, (8, 10), nothing,       (9, 10)      ]
    #  |----- left outside ------| |------  subarray --------| |- right outside -|

    # Find key 1 : does not exist in the subarray, no predecessor, should have (3, (4,10)) because it is the last element of the left outside.
    # Find key 2 : same
    # Find key 3 : same
    # Find key 4 : same
    # Find key 5 : same
    # Find key 7 : same
    # Find key 8 : exists at position 5, should have (5, (8, 10))
    # Find key 9 : does not exist in the subarray, should have (5, (8, 10))
    # Find key 100 : same

    look_for_key = [1, 2, 3, 4, 5, 7, 8, 9, 100]
    expected_output = [(3, (4, 10)), (3, (4, 10)), (3, (4, 10)), (3, (4, 10)), (3, (4, 10)), (3, (4, 10)), (5, (8, 10)), (5, (8, 10)), (5, (8, 10))]

    for i in 1:9
        output = DynamicSparseArrays.find(array, look_for_key[i], 4, 6)
        @test output == expected_output[i]
    end

    return
end