function spMv1()
    row = rand(rng, 1:100, 50)
    col = rand(rng, 1:100, 50)
    values =  rand(rng, 1:10, 50)

    dyn_matrix = dynamicsparse(row, col, values, 100, 100)
    matrix = sparse(row, col, values, 100, 100)

    vec_rows = rand(rng, 1:100, 25)
    vec_values = rand(rng, 1:10, 25)

    dyn_vec = dynamicsparsevec(vec_rows, vec_values, 100)
    vec = sparsevec(vec_rows, vec_values, 100)

    a = dyn_matrix * dyn_vec
    b = dyn_matrix * vec
    c = matrix * vec

    @test length(a) == 100
    @test length(b) == 100
    @test length(c) == 100

    @test a == b
    @test b == c
    @test a == c

    @test typeof(a) == SparseVector{Int,Int}
    @test typeof(b) == SparseVector{Int,Int}
    @test typeof(c) == SparseVector{Int,Int}
end
