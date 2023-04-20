function test_vec_display()
    I2 = ['a', 'c', 'e']
    V2 = [1, 1, 1]
    vec = DynamicSparseArrays.dynamicsparsevec(I2, V2)
    @show vec
end


function test_matrix_display()
    I = ['a', 'a', 'a', 'b', 'b', 'c', 'd', 'd', 'd'] #rows
    J = ['x', 'x', 'x', 'y', 'y', 'y', 'z', 'z', 'z'] #columns
    V = [20, 30, 40, 20, 40, 50, 30, 50, 70] #value
    matrix = DynamicSparseArrays.dynamicsparse(I, J, V)
    @show matrix
end