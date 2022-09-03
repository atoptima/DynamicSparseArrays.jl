function spMv1()
    row = rand(rng, 1:110, 50)
    col = rand(rng, 1:100, 50)
    values =  rand(rng, 1:10, 50)

    dyn_matrix = dynamicsparse(row, col, values, 110, 100)
    matrix = sparse(row, col, values, 110, 100)

    vec_rows1 = rand(rng, 1:100, 25)
    vec_values1 = rand(rng, 1:10, 25)

    dyn_vec1 = dynamicsparsevec(vec_rows1, vec_values1, 100)
    vec1 = sparsevec(vec_rows1, vec_values1, 100)

    a = dyn_matrix * dyn_vec1
    b = dyn_matrix * vec1
    c = matrix * vec1

    @test length(a) == 110
    @test length(b) == 110
    @test length(c) == 110

    @test a == b == c

    @test typeof(a) == SparseVector{Int,Int}
    @test typeof(b) == SparseVector{Int,Int}
    @test typeof(c) == SparseVector{Int,Int}

    vec_rows2 = rand(rng, 1:110, 25)
    vec_values2 = rand(rng, 1:10, 25)

    dyn_vec2 = dynamicsparsevec(vec_rows2, vec_values2, 110)
    vec2 = sparsevec(vec_rows2, vec_values2, 110)

    d = transpose(dyn_matrix) * dyn_vec2
    e = transpose(dyn_matrix) * vec2
    f = transpose(matrix) * vec2

    @test length(d) == 100
    @test typeof(d) == SparseVector{Int,Int}
    
    @test d == e == f

    g = dyn_vec1 * transpose(dyn_matrix)
    h = vec1 * transpose(dyn_matrix)
    @test g == h == a

    i = vec2 * dyn_matrix
    j = dyn_vec2 * dyn_matrix
    @test i == j == d
end

function addition()
    vec_rows1 = rand(rng, 1:100, 25)
    vec_values1 = rand(rng, 1:10, 25)

    dyn_vec1 = dynamicsparsevec(vec_rows1, vec_values1, 100)
    vec1 = sparsevec(vec_rows1, vec_values1, 100)

    vec_rows2 = rand(rng, 1:100, 25)
    vec_values2 = rand(rng, 1:10, 25)

    dyn_vec2 = dynamicsparsevec(vec_rows2, vec_values2, 100)
    vec2 = sparsevec(vec_rows2, vec_values2, 100)

    classic_sum = vec1 + vec2

    @test dyn_vec1 + dyn_vec2 == classic_sum
    @test vec1 + dyn_vec2 == classic_sum
    @test dyn_vec1 + vec2 == classic_sum
end

function subtraction()
    vec_rows1 = rand(rng, 1:100, 25)
    vec_values1 = rand(rng, 1:10, 25)

    dyn_vec1 = dynamicsparsevec(vec_rows1, vec_values1, 100)
    vec1 = sparsevec(vec_rows1, vec_values1, 100)

    vec_rows2 = rand(rng, 1:100, 25)
    vec_values2 = rand(rng, 1:10, 25)

    dyn_vec2 = dynamicsparsevec(vec_rows2, vec_values2, 100)
    vec2 = sparsevec(vec_rows2, vec_values2, 100)

    classic_sub = vec1 - vec2

    @test dyn_vec1 - dyn_vec2 == classic_sub
    @test vec1 - dyn_vec2 == classic_sub
    @test dyn_vec1 - vec2 == classic_sub
    @test -dyn_vec1 == -vec1
    @test -dyn_vec2 == -vec2
end

