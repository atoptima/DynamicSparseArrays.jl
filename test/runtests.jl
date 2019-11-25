using DynamicSparseArrays, Test, Random

rng = MersenneTwister(1234123)

include("unit/rebalance.jl")

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
    @test matrix[1,3] == 8 + 2
    @test matrix[4,7] == 2 + 2
    @test matrix[3,18] == -5 + 1
    @test matrix[5,9] == 3
    @test matrix[5,2] == 1
    @test matrix[5,1] == 3
    @test matrix[2,3] == 10
    @test matrix[1,3] == 5
    return
end

function pcsc_creation()
    keys = [[1, 2, 3], [2, 6, 7], [1, 6, 8]]
    values = [[2, 3, 4], [2, 4, 5], [3, 5, 7]]
    ppma = PartitionedPackedMemoryArray(keys, values)
    @test nbpartitions(ppma) == 3

    for (id, pos) in enumerate(ppma.semaphores)
        (key, sem_nb) = ppma.pma.array[pos]
        @test key == DynamicSparseArrays.semaphore_key(Int)
        @test sem_nb == id
    end

    keys = [[1, 2, 3, 1, 2], [2, 6, 7, 7, 5], [1, 6, 8, 2, 1]]
    values = [[2, 3, 4, 1, 1], [2, 4, 5, 1, 1], [3, 5, 7, 1, 1]]
    ppma = PartitionedPackedMemoryArray(keys, values)
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
        ppma[1, i] = 10
    end

    for i in 1:100
        @test ppma[1,i] == 10
    end
    return
end

function pcsc_instance(nbpartitions)
    partitions = Vector{Dict{Int, Float64}}()
    for p in 1:nbpartitions
        push!(partitions, Dict{Int, Float64}( 
            rand(rng, 1:10000) => rand(rng, 1:0.1:100) for i in 10:rand(rng, 20:1000)
        ))
    end
    return partitions
end

function pcsc_insertions_and_gets()
    nbpartitions = 42
    partitions = pcsc_instance(nbpartitions)
    K = [collect(keys(partition)) for partition in partitions]
    V = [collect(values(partition)) for partition in partitions]
    ppma = PartitionedPackedMemoryArray(K, V)

    # find
    for i in 1:100000
        partition = rand(rng, 1:nbpartitions)
        key = rand(rng, 1:10000)
        value = get(partitions[partition], key, 0.0)
        @test ppma[partition, key] == value
    end

    # insertions
    for i in 1:100000 
        partition = rand(rng, 1:nbpartitions)
        key = rand(rng, 1:10000)
        value = rand(rng, 1:0.1:100)
        ppma[partition, key] += value
        if !haskey(partitions[partition], key)
            partitions[partition][key] = 0.0
        end
        partitions[partition][key] += value
    end

    for partition in 1:nbpartitions
        for (key, val) in partitions[partition]
            @test ppma[partition, key] == val
        end
    end
    return
end

function pma()
    @testset "Instantiation (with multiple elements)" begin
        dynsparsevec_instantiation()
    end
    @testset "Insertions & finds" begin
        dynsparsevec_insertions_and_gets()
    end
    return
end

function pcsc()
    @testset "Creation of a packed compressed sparse row matrix" begin
        pcsc_creation()
    end
    @testset "Insertions & finds" begin
        pcsc_insertions_and_gets()
    end
    return
end

function dynamicsparse_tests()
    @testset "Instantiation (with multiple elements)" begin
        #dynsparsematrix_instantiation()
    end
end

test_rebalance(100, 10)
test_rebalance(1000, 8)
test_rebalance(500, 11)
test_rebalance(497, 97)
test_rebalance(855, 17)
test_rebalance(1000000, 5961)

test_rebalance_with_semaphores(100, 10)
test_rebalance_with_semaphores(1000, 8)
test_rebalance_with_semaphores(500, 11)
test_rebalance_with_semaphores(497, 97)
test_rebalance_with_semaphores(855, 17)
test_rebalance_with_semaphores(1000000, 5961)

pma()
pcsc()
dynamicsparse_tests()