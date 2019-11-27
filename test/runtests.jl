using DynamicSparseArrays, Test, Random

rng = MersenneTwister(1234123)

include("unit/unitests.jl")

function dynsparsevec_instantiation()
    I = [1, 2, 5, 5, 3, 10, 1, 8, 1, 5]
    V = [1.0, 3.5, 2.1, 8.5, 2.1, 1.1, 5.0, 7.8, 1.1, 2.0]

    vec = dynamicsparsevec(I,V)

    @test repr(vec) == "16-element DynamicSparseArrays.PackedMemoryArray{Int64,Float64,DynamicSparseArrays.NoPredictor} with 6 stored entries.\n"

    @test vec[1] == 1.0 + 1.1 + 5.0
    @test vec[2] == 3.5
    @test vec[3] == 2.1
    @test vec[4] == 0.0
    @test vec[5] == 2.1 + 8.5 + 2.0
    @test vec[8] == 7.8
    @test vec[10] == 1.1

    vec2 = dynamicsparsevec(I,V,*)
    @test vec2[1] == 1.0 * 1.1 * 5.0
    @test vec2[2] == 3.5
    @test vec2[3] == 2.1
    @test vec2[5] == 2.1 * 8.5 * 2.0
    @test vec2[6] == 0.0
    @test vec2[8] == 7.8
    @test vec2[10] == 1.1
    return
end

function dynsparsevec_insertions_and_gets()
    kv1 = Dict{Int, Float64}(
        rand(rng, 1:10000000000) => rand(rng, 1:0.1:10000) for i in 1:1000000
    )
    I = collect(keys(kv1))
    V = collect(values(kv1))
    pma = dynamicsparsevec(I,V)
    for (k,v) in kv1
        @test pma[k] == v
    end

    # insert 1000000 more elements
    kv2 = Dict{Int, Float64}(
        rand(rng, 1:10000000000) => rand(rng, 1:0.1:10000) for i in 1:1000000
    )
    for (k,v) in kv2
        pma[k] = v
    end
    kv3 = merge(kv1, kv2)
    for (k,v) in kv3
        @test pma[k] == v
    end

    @test ndims(pma) == 1
    @test size(pma) == (length(kv3),)
    @test length(pma) == length(kv3)

    kv4 = Dict{Int, Float64}(
        rand(rng, 1:100000) => rand(rng, 1:0.1:10000) for i in 1:10
    )
    I = collect(keys(kv4))
    V = collect(values(kv4))
    pma = dynamicsparsevec(I,V)
    for i in 1:100000
        pma[i] = 10.0
    end
    for i in 1:100000
        @test pma[i] == 10
    end
    return
end

function dynamicsparsevec_deletions()
    I = [1, 2, 5, 5, 3, 10, 1, 8, 1, 5]
    V = [1.0, 3.5, 2.1, 8.5, 2.1, 1.1, 5.0, 7.8, 1.1, 2.0]

    vec = dynamicsparsevec(I,V)

    @test repr(vec) == "16-element DynamicSparseArrays.PackedMemoryArray{Int64,Float64,DynamicSparseArrays.NoPredictor} with 6 stored entries.\n"

    @test vec[1] == 1.0 + 1.1 + 5.0
    @test vec[2] == 3.5
    @test vec[3] == 2.1
    @test vec[4] == 0.0
    @test vec[5] == 2.1 + 8.5 + 2.0
    @test vec[8] == 7.8
    @test vec[10] == 1.1

    vec[1] = 0
    @test vec[1] == 0

    vec[2] = 0
    @test vec[2] == 0

    vec[3] = 0
    @test vec[3] == 0
    return
end

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

function pma()
    @testset "Instantiation (with multiple elements) in dyn sparse vector" begin
        dynsparsevec_instantiation()
    end
    @testset "Insertions & finds in dyn sparse vector" begin
        dynsparsevec_insertions_and_gets()
    end
    @testset "Deletions in dyn sparse vector" begin
        dynamicsparsevec_deletions()
    end
    return
end

function pcsc()
    @testset "Creation of a PackedCSC matrix" begin
        pcsc_creation()
    end
    @testset "Insertions & finds in PackedCSC matrix" begin
        pcsc_insertions_and_gets()
    end
    return
end

function dynamicsparse_tests()
    @testset "Instantiation (with multiple elements) in MappedPackedCSC matrix" begin
        dynsparsematrix_instantiation()
    end
    @testset "Insertions & finds in MappedPackedCSC matrix" begin
        dynsparsematrix_insertions_and_gets()
    end
end

unit_tests()
pma()
pcsc()
dynamicsparse_tests()