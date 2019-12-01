function pcsc_factory(nbpartitions, prob_empty_partition::Float64 = 0.0)
    partitions = Vector{Dict{Int, Float64}}()
    for p in 1:nbpartitions
        if rand(rng, 0:0.001:1) >= prob_empty_partition
            push!(partitions, Dict{Int, Float64}( 
                rand(rng, 1:10000) => rand(rng, 1:0.1:100) for i in 10:rand(rng, 20:1000)
            ))
        else
            push!(partition, Dict{Int, Float64}())
        end
    end
    return partitions
end

function pcsc_simple_use()
    # Test A.0 : Create an empty matrix
    # pcsc = PackedCSC()
    # @show length(pcsc) == 0

    # Test A.1 : Create the matrix, check semaphores, & check key order
    keys = [[1, 2, 3], [2, 6, 7], [1, 6, 8]]
    values = [[2, 3, 4], [2, 4, 5], [3, 5, 7]]

    pcsc1 = PackedCSC(keys, values)
    @test nbpartitions(pcsc1) == 3
    check_semaphores(pcsc1.pma.array, pcsc1.semaphores)
    check_key_order(pcsc1.pma.array, pcsc1.semaphores)
    @test ndims(pcsc1) == 2
    @test length(pcsc1) == 9 # nb of non-zero entries
    @test size(pcsc1)[1] > length(pcsc1)
    @test size(pcsc1)[2] == 3
    
    # Test A.2 : Check value of entries
    matrix = [2 0 3; 3 2 0; 4 0 0; 0 0 0; 0 0 0; 0 4 5; 0 5 0; 0 0 7]
    nr, nc = size(matrix)
    #@test pcsc1 == matrix # TODO
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
    @test size(pcsc1)[2] == 3

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
    @test size(pcsc1)[2] == 5 # 2 new partitions

    pcsc1[1,4] = 2
    @test length(pcsc1) == 12
    check_semaphores(pcsc1.pma.array, pcsc1.semaphores)
    check_key_order(pcsc1.pma.array, pcsc1.semaphores)

    # Test A.7 : delete columns (deleting a column is irreversible)
    nb_elems_in_part_2 = length(pcsc1[:,2])
    deletepartition!(pcsc1, 2)
    @test size(pcsc1)[2] == 4
    @test_broken length(pcsc1) ==  12 - nb_elems_in_part_2 #TODO
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
    @test size(pcsc2)[2] == 4

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

function dynsparsematrix_factory(nbrows, nbcols, density::Float64 = 0.05)
    I = Vector{Int}()
    J = Vector{Int}()
    V = Vector{Float64}()
    for i in 1:nbrows, j in 1:nbcols
        if rand(rng, 0:0.001:1) <= density
            push!(I, i)
            push!(J, j)
            push!(V, rand(rng, 0:0.0001:1000))
        end
    end
    return I, J, V
end

function dynsparsematrix_simple_use()
    # Test A

    J = [1, 1, 1, 2, 2, 2, 3, 3, 3]
    I = [1, 2, 3, 2, 6, 7, 1, 6, 8]
    V = [2, 3, 4, 2, 4, 5, 3, 5, 7]
    matrix = dynamicsparse(I,J,V)
    check_semaphores(matrix.pcsc.pma.array, matrix.pcsc.semaphores)
    check_key_order(matrix.pcsc.pma.array, matrix.pcsc.semaphores)
    @test ndims(matrix) == 2
    @test length(matrix) == 9 # nb of non-zero entries
    @test size(matrix)[1] > length(matrix)
    @test size(matrix)[2] == 3
    
    # Test A.2 : Check value of entries
    matrix2 = [2 0 3; 3 2 0; 4 0 0; 0 0 0; 0 0 0; 0 4 5; 0 5 0; 0 0 7]
    nr, nc = size(matrix2)
    #@test pcsc1 == matrix # TODO
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

    @test length(matrix) == 10
    @test size(matrix)[2] == 3

    #@test pcsc1 == matrix # TODO
    for i in 1:nr, j in 1:nc
        @test matrix[i,j] == matrix2[i,j]
    end

    # Test A.4 : make a copy of the matrix
    matrix3 = MappedPackedCSC(matrix)
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

    @test_throws ArgumentError matrix[1,4] = 2 # Cannot create column 4 because the last created is 5

    check_semaphores(matrix.pcsc.pma.array, matrix.pcsc.semaphores)
    check_key_order(matrix.pcsc.pma.array, matrix.pcsc.semaphores)

    # Test A.7 : delete columns (deleting a column is irreversible)
    nb_elems_in_part_2 = length(matrix[:,2])
    deletecolumn!(matrix, 2)
    @test size(matrix)[2] == 3
    @test_broken length(matrix) ==  11 - nb_elems_in_part_2 #TODO
    nb_sem = check_semaphores(matrix.pcsc.pma.array, matrix.pcsc.semaphores)
    @test nb_sem == 3
    check_key_order(matrix.pcsc.pma.array, matrix.pcsc.semaphores)

    @test_throws ArgumentError matrix[1,2] = 1 # because column 2 has been deleted
    
    
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
    # Test 2 : Add value in a non-empty row but empty column, should not work
    # because the column is not registered and its id (2) is less than the last
    # id (18).
    @test_throws ArgumentError matrix[1,2] = 21
    @test matrix[1,2] == 0 # because the column does not exist
    # Test 3 : Add value in a non-empty row but empty column,
    # works because 33 > 18
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

    check_semaphores(matrix.pcsc.pma.array, matrix.pcsc.semaphores)
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

    check_semaphores(matrix.pcsc.pma.array, matrix.pcsc.semaphores)

    DynamicSparseArrays.deletecolumn!(matrix, 3)
    check_semaphores(matrix.pcsc.pma.array, matrix.pcsc.semaphores)

    for i in 1:5
        @test matrix[i,3] == 0
    end
    return
end