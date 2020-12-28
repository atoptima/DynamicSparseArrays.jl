function pcsc_simple_use()
    # Test A.0 : Create an empty matrix
    #pcsc = PackedCSC(Int[], Float64[])
    #@show length(pcsc) == 0

    # Test A.1 : Create the matrix, check semaphores, & check key order
    keys = [[1, 2, 3], [2, 6, 7], [1, 6, 8]]
    values = [[2, 3, 4], [2, 4, 5], [3, 5, 7]]

    pcsc1 = PackedCSC(keys, values)
    @test nbpartitions(pcsc1) == 3
    check_semaphores(pcsc1.pma.array, pcsc1.semaphores)
    check_key_order(pcsc1.pma.array, pcsc1.semaphores)
    @test ndims(pcsc1) == 2
    @test length(pcsc1) == 9 # nb of non-zero entries
    @test nbpartitions(pcsc1) == 3

    # Test A.2 : Check value of entries
    matrix = [2 0 3; 3 2 0; 4 0 0; 0 0 0; 0 0 0; 0 4 5; 0 5 0; 0 0 7]
    nr, nc = size(matrix)
    @test_broken pcsc1 == matrix # TODO
    for i in 1:nr, j in 1:nc
        @test matrix[i,j] == pcsc1[i,j]
    end

    # Test A.3 : set some entries
    matrix[1,1] = 4
    pcsc1[1,1] = 4  # set
    matrix[1,2] += 3
    pcsc1[1,2] += 3 # new element
    matrix[3,1] = 0
    pcsc1[3,1] = 0  # rm
    matrix[4,2] = 1
    pcsc1[4,2] = 1 # new element

    @test length(pcsc1) == 10
    @test nbpartitions(pcsc1) == 3

    #@test pcsc1 == matrix # TODO
    for i in 1:nr, j in 1:nc
        @test matrix[i,j] == pcsc1[i,j]
    end

    # Test A.4 : make a copy of the matrix
    pcsc3 = PackedCSC(pcsc1)
    @test_broken pcsc1 == pcsc3 # TODO

    # Test A.5 : retrieve columns & rows
    # Test A.5.1 : retrieve a row
    row = pcsc1[2, :]
    row_from_matrix = matrix[2, :]

    @test length(row) == 2
    for i in 1:length(row_from_matrix) # TODO : good test
        @test row[i] == row_from_matrix[i]
    end

    # Test A.5.2 : retrieve a column
    column = pcsc1[:, 2]
    col_from_matrix = pcsc1[:, 2]

    @test length(column) == 5
    for i in 1:length(col_from_matrix)
        @test column[i] == col_from_matrix[i]
    end

    # Test A.5.3 : retrieve an empty row
    for i in 1:3
        pcsc3[2,i] = 0
    end
    @test length(pcsc3[2,:]) == 0

    # Test A.5.4 : retrieve an empty column
    for i in 1:8
        pcsc3[i,2] = 0
    end
    @test length(pcsc3[:,2]) == 0

    # Test A.6 : add columns
    pcsc1[10,5] = 9 # new element and new column
    @test length(pcsc1) == 11
    @test nbpartitions(pcsc1) == 5 # 2 new partitions

    pcsc1[1,4] = 2
    @test length(pcsc1) == 12
    check_semaphores(pcsc1.pma.array, pcsc1.semaphores)
    check_key_order(pcsc1.pma.array, pcsc1.semaphores)

    # Test A.7 : delete columns (deleting a column is irreversible)
    nb_elems = length(pcsc1)
    nb_elems_in_part_2 = length(pcsc1[:,2])
    deletepartition!(pcsc1, 2)
    @test nbpartitions(pcsc1) == 4
    @test length(pcsc1) ==  nb_elems - nb_elems_in_part_2 #TODO
    nb_sem = check_semaphores(pcsc1.pma.array, pcsc1.semaphores)
    @test nb_sem == 4
    check_key_order(pcsc1.pma.array, pcsc1.semaphores)

    @test_throws ErrorException pcsc1[1,2] = 1 # because column 2 has been deleted

    # Test B.1
    keys = [[1, 2, 3, 1, 2], Int[], [2, 6, 7, 7, 5], [1, 6, 8, 2, 1]]
    values = [[2, 3, 4, 1, 1], Int[], [2, 4, 5, 1, 1], [3, 5, 7, 1, 1]]
    pcsc2 = PackedCSC(keys, values)
    @test nbpartitions(pcsc2) == 4
    check_semaphores(pcsc2.pma.array, pcsc2.semaphores)
    check_key_order(pcsc2.pma.array, pcsc2.semaphores)
    @test length(pcsc2) == 11
    @test nbpartitions(pcsc2) == 4

    # Test B.2
    matrix = [3 0 0 4; 4 0 2 1; 4 0 0 0; 0 0 0 0; 0 0 1 0; 0 0 4 5; 0 0 6 0; 0 0 0 7]
    nr, nc = size(matrix)
    #@test pcsc2 == matrix # TODO
    for i in 1:nr, j in 1:nc
        @test matrix[i,j] == pcsc2[i,j]
    end
    return
end

function pcsc_insertions_and_gets()
    nbpartitions = 42
    partitions = pcsc_factory(nbpartitions)
    K = [collect(keys(partition)) for partition in partitions]
    V = [collect(values(partition)) for partition in partitions]
    ppma = PackedCSC(K, V)

    # find
    for i in 1:100000
        partition = rand(rng, 1:nbpartitions)
        key = rand(rng, 1:10000)
        value = get(partitions[partition], key, 0.0)
        @test ppma[key, partition] == value
    end

    # insertions
    for i in 1:100000
        partition = rand(rng, 1:nbpartitions)
        key = rand(rng, 1:10000)
        value = rand(rng, 1:0.1:100)
        ppma[key, partition] += value
        if !haskey(partitions[partition], key)
            partitions[partition][key] = 0.0
        end
        partitions[partition][key] += value
    end

    for partition in 1:nbpartitions
        for (key, val) in partitions[partition]
            @test ppma[key, partition] == val
        end
    end
    return
end

DynamicSparseArrays.semaphore_key(::Type{Char}) = ' '

function dynsparsematrix_simple_use()
    # Test A.0 : create a matrix and fill it
    I,J,V = dynsparsematrix_factory(1000, 1000, 0.1)
    matrix = dynamicsparse(I, J, V)

    I,J,V = dynsparsematrix_factory(1000, 1000, 0.2)
    for k in 1:length(I)
        matrix[I[k], J[k]] = V[k]
    end
    for k in 1:length(I)
        @test matrix[I[k], J[k]] == V[k]
    end

    # Test A
    J = [1, 1, 1, 2, 2, 2, 3, 3, 3]
    I = [1, 2, 3, 2, 6, 7, 1, 6, 8]
    V = [2, 3, 4, 2, 4, 5, 3, 5, 7]
    matrix = dynamicsparse(I,J,V)
    check_semaphores(matrix.colmajor.pcsc.pma.array, matrix.colmajor.pcsc.semaphores)
    check_key_order(matrix.colmajor.pcsc.pma.array, matrix.colmajor.pcsc.semaphores)
    check_semaphores(matrix.rowmajor.pcsc.pma.array, matrix.rowmajor.pcsc.semaphores)
    check_key_order(matrix.rowmajor.pcsc.pma.array, matrix.rowmajor.pcsc.semaphores)
    @test ndims(matrix) == 2
    @test length(matrix.colmajor) == length(matrix.rowmajor) == length(matrix) == 9 # nb of non-zero entries
    @test size(matrix)[2] == 3

    # Test A.2 : Check value of entries
    matrix2 = [2 0 3; 3 2 0; 4 0 0; 0 0 0; 0 0 0; 0 4 5; 0 5 0; 0 0 7]
    nr, nc = size(matrix2)
    @test_broken matrix == matrix2
    for i in 1:nr, j in 1:nc
        @test matrix[i,j] == matrix2[i,j]
    end

    # Test A.3 : set some entries
    matrix2[1,1] = 4
    matrix[1,1] = 4  # set
    matrix2[1,2] += 3
    matrix[1,2] += 3 # new element
    matrix2[3,1] = 0
    matrix[3,1] = 0  # rm
    matrix2[4,2] = 1
    matrix[4,2] = 1 # new element

    @test length(matrix.rowmajor) == length(matrix.colmajor) == 10
    @test size(matrix) == (7, 3)

    for i in 1:nr, j in 1:nc
        @test matrix[i,j] == matrix2[i,j]
    end

    # Test A.4 : make a copy of the matrix
    matrix3 = MappedPackedCSC(matrix.colmajor)
    @test_broken matrix3 == matrix

    # Test A.5 : retrieve columns & rows
    # Test A.5.1 : retrieve a row
    row = matrix[2, :]
    row_from_matrix = matrix2[2, :]

    @test length(row) == 2
    for i in 1:length(row_from_matrix) # TODO : good test
        @test row[i] == row_from_matrix[i]
    end

    # Test A.5.2 : retrieve a column
    column = matrix[:, 2]
    col_from_matrix = matrix2[:, 2]

    @test length(column) == 5
    for i in 1:length(col_from_matrix)
        @test column[i] == col_from_matrix[i]
    end

    # Test A.5.3 : retrieve an empty row
    for i in 1:3
        matrix3[2,i] = 0
    end
    @test length(matrix3[2,:]) == 0

    # Test A.5.4 : retrieve an empty column
    for i in 1:8
        matrix3[i,2] = 0
    end
    @test length(matrix3[:,2]) == 0

    # Test A.6 : add columns
    matrix[10,5] = 9 # new element and new column
    @test length(matrix) == 11
    @test size(matrix)[2] == 4 # 1 new partition

    matrix[1,-1] = 1 # add column at the very beginning
    matrix[1,4] = 2 # We can create column 4 even if the last created is 5
    matrix[3,4] = 5
    @test matrix[1,4] == 2
    @test matrix[3,4] == 5
    @test matrix[1,-1] == 1

    @test size(matrix)[2] == 6 # 2 new columns

    check_semaphores(matrix.colmajor.pcsc.pma.array, matrix.colmajor.pcsc.semaphores)
    check_key_order(matrix.colmajor.pcsc.pma.array, matrix.colmajor.pcsc.semaphores)
    check_semaphores(matrix.rowmajor.pcsc.pma.array, matrix.rowmajor.pcsc.semaphores)
    check_key_order(matrix.rowmajor.pcsc.pma.array, matrix.rowmajor.pcsc.semaphores)

    # Test A.7 : delete columns (and recreate the column)
    deletecolumn!(matrix, 2)
    @test size(matrix) == (8, 5)

    nb_sem1 = check_semaphores(matrix.colmajor.pcsc.pma.array, matrix.colmajor.pcsc.semaphores)
    nb_sem2 = check_semaphores(matrix.rowmajor.pcsc.pma.array, matrix.rowmajor.pcsc.semaphores)
    @test nb_sem1 == 5
    @test nb_sem2 == 8
    check_key_order(matrix.colmajor.pcsc.pma.array, matrix.colmajor.pcsc.semaphores)
    check_key_order(matrix.rowmajor.pcsc.pma.array, matrix.rowmajor.pcsc.semaphores)

    matrix[1,2] = 1
    @test matrix[1,2] == 1

    nb_sem1 = check_semaphores(matrix.colmajor.pcsc.pma.array, matrix.colmajor.pcsc.semaphores)
    nb_sem2 = check_semaphores(matrix.rowmajor.pcsc.pma.array, matrix.rowmajor.pcsc.semaphores)
    @test nb_sem1 == 6
    @test nb_sem2 == 8
    check_key_order(matrix.colmajor.pcsc.pma.array, matrix.colmajor.pcsc.semaphores)
    check_key_order(matrix.rowmajor.pcsc.pma.array, matrix.rowmajor.pcsc.semaphores)

    # Test B
    I = [1, 1, 2, 4, 3, 5, 1, 3, 1, 5, 1, 5, 4]
    J = [4, 3, 3, 7, 18, 9, 3, 18, 4, 2, 3, 1, 7]
    V = [1, 8, 10, 2, -5, 3, 2, 1, 1, 1, 5, 3, 2]
    matrix = dynamicsparse(I,J,V)
    @test matrix[1,4] == 1 + 1
    @test matrix[1,3] == 8 + 2 + 5
    @test matrix[4,7] == 2 + 2
    @test matrix[3,18] == -5 + 1
    @test matrix[5,9] == 3
    @test matrix[5,2] == 1
    @test matrix[5,1] == 3
    @test matrix[2,3] == 10

    # Test C (row & column keys with different type to test methods signatures)
    I = [1, 1, 2, 4, 1, 2, 4, 5, 5, 2]
    J = ['a', 'c', 'c', 'a', 'd', 'a', 'e', 'e', 'c', 'd']
    V = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    matrix = dynamicsparse(I,J,V)
    @test matrix[1, 'a'] == 1
    @test matrix[1, 'c'] == 2
    @test matrix[2, 'c'] == 3
    @test matrix[4, 'a'] == 4
    @test matrix[1, 'd'] == 5
    @test matrix[2, 'a'] == 6
    @test matrix[4, 'e'] == 7
    @test matrix[5, 'e'] == 8
    @test matrix[5, 'c'] == 9
    @test matrix[2, 'd'] == 10

    # add new column
    matrix[2, 'b'] = 11
    @test matrix[2, 'b'] == 11

    @test size(matrix) == (4, 5)

    # delete column
    deletecolumn!(matrix, 'a')
    @test matrix[1, 'a'] == 0
    @test matrix[2, 'a'] == 0

    deleterow!(matrix, 5)
    @test matrix[5, 'c'] == 0
    @test matrix[5, 'e'] == 0

    @test size(matrix) == (3, 4)
    return
end

function dynsparsematrix_insertions_and_gets()
    I = [1, 4, 3, 5]
    J = [4, 7, 18, 9]
    V = [1, 2, -5, 3]
    matrix = dynamicsparse(I,J,V)
    # Test 1 : Add value in an empty row but non-empty column
    matrix[2,7] = 8
    @test matrix[2,7] == 8
    # Test 2 : Add value in a non-empty row but empty column
    matrix[1,2] = 21
    @test matrix[1,2] == 21 # because the column does not exist
    # Test 3 : Add value in a non-empty row but empty column (at the end)
    matrix[10,33] = 21
    @test matrix[10,33] == 21
    # Test 4 : Add value in empty column and empty row
    matrix[55,54] = 53
    @test matrix[55,54] == 53

    @test matrix[1,4] == 1
    @test matrix[4,7] == 2
    @test matrix[3,18] == -5
    @test matrix[5,9] == 3

    nb_rows = 340
    nb_cols = 1000
    I, J, V = dynsparsematrix_factory(nb_rows, nb_cols)
    matrix = dynamicsparse(I,J,V)

    for k in 1:length(I)
        @test matrix[I[k],J[k]] == V[k]
    end

    # Adding new columns
    for col in nb_cols:5000
        matrix[1,col] = 1
    end

    for col in nb_cols:5000
        @test matrix[1,col] == 1
    end

    check_semaphores(matrix.colmajor.pcsc.pma.array, matrix.colmajor.pcsc.semaphores)
    check_semaphores(matrix.rowmajor.pcsc.pma.array, matrix.rowmajor.pcsc.semaphores)
end

function dynsparsematrix_deletions()
    I = [1, 1, 2, 4, 3, 5, 1, 3, 1, 5, 1, 5, 4]
    J = [4, 3, 3, 7, 18, 9, 3, 18, 4, 2, 3, 1, 7]
    V = [1, 8, 10, 2, -5, 3, 2, 1, 1, 1, 5, 3, 2]
    matrix = dynamicsparse(I,J,V)
    @test matrix[1,4] == 1 + 1
    @test matrix[1,3] == 8 + 2 + 5
    @test matrix[4,7] == 2 + 2
    @test matrix[3,18] == -5 + 1
    @test matrix[5,9] == 3
    @test matrix[5,2] == 1
    @test matrix[5,1] == 3
    @test matrix[2,3] == 10

    check_semaphores(matrix.colmajor.pcsc.pma.array, matrix.colmajor.pcsc.semaphores)
    check_semaphores(matrix.rowmajor.pcsc.pma.array, matrix.rowmajor.pcsc.semaphores)

    DynamicSparseArrays.deletecolumn!(matrix, 3)
    check_semaphores(matrix.colmajor.pcsc.pma.array, matrix.colmajor.pcsc.semaphores)
    check_semaphores(matrix.rowmajor.pcsc.pma.array, matrix.rowmajor.pcsc.semaphores)

    for i in 1:5
        @test matrix[i,3] == 0
    end
    return
end

function dynsparsematrix_fill_mode()
    matrix = dynamicsparse(Int, Int, Int)

    values =  [ 1 0 0 2 0 7 0 0 0 9 1 2;
                0 3 0 0 1 1 0 0 0 1 0 2;
                0 0 0 1 1 2 0 0 1 2 0 0;
                0 0 0 0 0 0 0 1 0 0 0 1;
                1 2 0 0 0 0 0 0 1 0 0 0 ]

    for i in axes(values, 1)
        colids = findall(id -> id != 0, values[i, :])
        addrow!(matrix, i, colids, values[i, colids])
    end

    for i in axes(values, 1)
        row = matrix[i, :]
        for j in axes(values, 2)
            @test row[j] == values[i,j]
        end
    end

    matrix[1, 2] = 2
    matrix[1, 1] = 1

    values[1, 2] = 2
    values[1, 1] += 1

    closefillmode!(matrix)

    for i in axes(values, 1), j in axes(values, 2)
        @test matrix[i, j] == values[i, j]
        @test matrix.colmajor[i, j] == values[i, j]
        @test matrix.rowmajor[j, i] == values[i, j]
    end

    ## Second test
    row = rand(rng, 1:1000, 10_000)
    col = rand(rng, 1:1000, 10_000)
    values =  rand(rng, 1:100_000, 10_000)

    matrix = dynamicsparse(Int, Int, Int)

    matrix2 = sparse(row, col, values, 1000, 1000)

    for i in 1:10000
        matrix[row[i], col[i]] = values[i]
    end
    closefillmode!(matrix)

    for i in 1:100, j in 1:1000
        @test matrix[i, j] == matrix2[i, j]
        @test matrix.colmajor[i, j] == matrix2[i, j]
        @test matrix.rowmajor[j, i] == matrix2[i, j] 
    end

    ## Third test
    row = rand(rng, 1:1000, 10_000)
    col = rand(rng, 1:1000, 10_000)
    values =  rand(rng, 1:100_000, 10_000)

    matrix = dynamicsparse(Int, Int, Int; fill_mode = false)

    matrix2 = sparse(Int[], Int[], Int[], 1000, 1000)

    for i in 1:10000
        matrix[row[i], col[i]] = values[i]
        matrix2[row[i], col[i]] = values[i] # combine works only if fill_mode is enable
    end

    for i in 1:1000, j in 1:1000
        @test matrix[i, j] == matrix2[i, j]
        @test matrix.colmajor[i, j] == matrix2[i, j]
        @test matrix.rowmajor[j, i] == matrix2[i, j] 
    end

    return
end