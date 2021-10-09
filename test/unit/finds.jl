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


    # Test 3 : Explanation of a bug
    # It turned out that some new elements were inserted before the semaphore 
    # making the dynamic matrix absolutely wrong.

    # We consider the following elements array.
    # The semaphore is the element (3, 10)
    # We want to insert two new values in the 1st column. Let's see what the `find` method returns.

    #           out of matrix   | ------------------------ 1st column  ------------------------ | -------------- 2nd column -------------- |
    #                           |  semaphore                                                    | semaphore                                |
    #                           |    ↓↓↓                                                        |   ↓↓↓                                    |
    array = [       nothing,      (3, 10), nothing, nothing, (9, 10), nothing, (10, 10), nothing, (3, 10), nothing, nothing, (2,1), nothing]
    #        |-- left outside --||--------------------------------- subarray -------------------||--------- right outside -----------------|

    # We want to insert a new element of key 4.
    # The element does not exist, and semaphore key < 4.
    # Therefore, `find` returns the position of the sempahore & the semaphore.
    @test DynamicSparseArrays.find(array, 4, 2, 8) == (2, (3,10))

    # We want to insert a new element of key 2.
    # The element does not exist, and semaphore key > 2.
    # Method `find` returns the last element of the left outside -> (0, nothing)
    @test DynamicSparseArrays.find(array, 2, 2, 8) == (0, nothing)

    # It's a postcondition of the `find` methods but wasn't taken into account
    # in the implementation of `setindex` method of the dynamic sparse matrix. 
    # It creates a bug.

    ## The fix consists in putting the semaphore outside the subarray.

    #           out of matrix             | ------------------- 1st column  ------------------ |          | --------- 2nd column --------- |
    #                              sem.   |                                                    |   sem.   |                                |
    #                              ↓↓↓    |                                                    |   ↓↓↓    |                                |
    array = [       nothing,      (3, 10), nothing, nothing, (9, 10), nothing, (10, 10), nothing, (3, 10), nothing, nothing, (2,1), nothing]
    #        |------- left outside ------||----------------------- subarray -------------------||------------ right outside ---------------|

    @test DynamicSparseArrays.find(array, 4, 3, 8) == (2, (3,10))
    @test DynamicSparseArrays.find(array, 2, 3, 8) == (2, (3,10)) # bug fixed :)

    # What happens if the column is empty?
    # We insert in a new element in 2nd column

    #        out of matrix                | --------- 1st column  ------------ |       | -- 2nd -- |        | ----- 3rd column ---- |
    array = [       nothing,      (3, 10), nothing, (9, 10), nothing, (10, 10), (3, 10),            (3, 10), nothing, (2,1), nothing]

    # position of semaphores : 2, 7, and 8
    # try to insert new elements :
    @test DynamicSparseArrays.find(array, 2, 3, 6) == (2, (3,10))
    @test DynamicSparseArrays.find(array, 2, 8, 7) == (7, (3,10))
    @test DynamicSparseArrays.find(array, 1, 9, 11) == (8, (3,10))
    return
end