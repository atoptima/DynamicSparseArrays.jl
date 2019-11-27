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

function pcsc_creation()
    keys = [[1, 2, 3], [2, 6, 7], [1, 6, 8]]
    values = [[2, 3, 4], [2, 4, 5], [3, 5, 7]]
    ppma = PackedCSC(keys, values)
    @test nbpartitions(ppma) == 3

    for (id, pos) in enumerate(ppma.semaphores)
        (key, sem_nb) = ppma.pma.array[pos]
        @test key == DynamicSparseArrays.semaphore_key(Int)
        @test sem_nb == id
    end

    keys = [[1, 2, 3, 1, 2], [2, 6, 7, 7, 5], [1, 6, 8, 2, 1]]
    values = [[2, 3, 4, 1, 1], [2, 4, 5, 1, 1], [3, 5, 7, 1, 1]]
    ppma = PackedCSC(keys, values)
    @test nbpartitions(ppma) == 3

    for (id, pos) in enumerate(ppma.semaphores)
        (key, sem_nb) = ppma.pma.array[pos]
        @test key == DynamicSparseArrays.semaphore_key(Int)
        @test sem_nb == id
    end

    # Check if order is respected inside each partition
    prev_key = -1 # key of semaphore is 0
    sum_val = 0
    for couple in ppma.pma.array
        if couple != nothing
            (key, value) = couple
            if key != 0
                @test prev_key < key
                sum_val += value
            end
            prev_key = key
        end
    end
    @test sum_val == sum(sum(values))

    for i in 1:100
        ppma[i, 1] = 10
    end

    for i in 1:100
        @test ppma[i, 1] == 10
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

function pcsc_deletions()
    # Test 1 : Deletions of elements
    keys = [[1, 2, 3, 1, 2], [2, 6, 7, 7, 5], [1, 6, 8, 2, 1]]
    values = [[2, 3, 4, 1, 1], [2, 4, 5, 1, 1], [3, 5, 7, 1, 1]]
    pcsc = PackedCSC(keys, values)
    @test nbpartitions(pcsc) == 3
    @test pcsc[1, 1] == 2 + 1
    @test pcsc[2, 1] == 3 + 1
    @test pcsc[3, 1] == 4

    pcsc[1, 1] = 0
    pcsc[2, 1] = 0
    pcsc[3, 1] = 0
    @test pcsc[1, 1] == 0
    @test pcsc[2, 1] == 0
    @test pcsc[3, 1] == 0

    check_semaphores(pcsc.pma.array, pcsc.semaphores)

    DynamicSparseArrays.deletepartition!(pcsc, 1)
    check_semaphores(pcsc.pma.array, pcsc.semaphores)
    
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

function dynsparsematrix_instantiation()
    I = [1, 4, 3, 5]
    J = [4, 7, 18, 9]
    V = [1, 2, -5, 3]
    matrix = dynamicsparse(I,J,V)
    @test matrix[1,4] == 1
    @test matrix[4,7] == 2
    @test matrix[3,18] == -5
    @test matrix[5,9] == 3

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

    # TODO
end