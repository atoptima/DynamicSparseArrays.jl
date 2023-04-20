function test_vec_display()
    I2 = ['a', 'c', 'e']
    V2 = [1, 1, 1]
    vec = DynamicSparseArrays.dynamicsparsevec(I2, V2)
    @show vec
end

