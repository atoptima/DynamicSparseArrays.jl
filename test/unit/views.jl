function test_views()
    I = [1, 1, 2, 4, 3, 5, 1, 4, 1, 5, 1, 5, 4, 4, 3, 9, 1]
    J = [4, 3, 3, 7, 18, 9, 3, 18, 4, 2, 3, 1, 7, 3, 3, 3, 18]
    V = [1, 8, 10, 2, -5, 3, 2, 1, 1, 1, 5, 3, 2, 1, 7, 8, 1]
    matrix = dynamicsparse(I,J,V)

    # get the row with id 5
    ids = Int[]
    vals = Int[]
    for (id, val) in view(matrix, 5, :)
        push!(ids, id)
        push!(vals, val)
    end
    @test ids == [1, 2, 9]
    @test vals == [3, 1, 3]

    # get the column with id 3
    ids = Int[]
    vals = Int[]
    slice = view(matrix, :, 3)
    for (id, val) in slice
        push!(ids, id)
        push!(vals, val)
    end
    @test ids == [1,2,3,4,9]
    @test vals == [15,10,7,1,8]

    ids = Int[]
    vals = Int[]
    for (id, val) in @view matrix[:, 18]
        push!(ids, id)
        push!(vals, val)
    end
    @test ids == [1,3,4]
    @test vals == [1,-5,1]
end
