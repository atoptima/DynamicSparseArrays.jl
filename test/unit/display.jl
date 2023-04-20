function test_vec_display()
    I2 = ['a', 'c', 'e']
    V2 = [1, 1, 1]
    vec = DynamicSparseArrays.dynamicsparsevec(I2, V2)
    @show vec
end


function test_matrix_display()
    I = [1, 2, 3, 2, 6, 7, 1, 6, 8] #rows
    J = [1, 1, 1, 2, 2, 2, 3, 3, 3] #columns
    V = [20, 30, 40, 20, 40, 50, 30, 50, 70] #value
    matrix = DynamicSparseArrays.dynamicsparse(I, J, V)
    @show matrix
end