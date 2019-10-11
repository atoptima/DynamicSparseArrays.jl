using DynamicSparseArrays, Test, BenchmarkTools, Random

rng = MersenneTwister(1234123);

function test_insert_benchmark()
    st = Dict{Int, Float64}()
    pma = PackedMemoryArray{Int,Float64}(10)
    for i in 1:30
        k = rand(rng, 1:1000000)
        v = rand(rng, 1:0.001:10000)
        pma[k] = v
        st[k] = v
    end
    @show pma.capacity
    pos = 1
    for (k,v) in st
        @show pos
        @test v == pma[k]
        pos += 1
    end
    return
end

function create(keys_array, values_array)
    pma = PackedMemoryArray(keys_array, values_array)
    # for (i, k) in enumerate(keys_array)
    #     @test pma[k] == values_array[i]
    # end
    return pma
end

function insert(pma, dict)
    for (k,v) in dict
        pma[k] = v
    end
end

function main()
    #some_test_to_improve()
    #pma = PackedMemoryArray{Int,Float64}(100)
    # @show pma.capacity
    # @show pma.segment_capacity
    # @show pma.nb_segments
    # @show pma.height

    # @test pma[2] == 0
    # pma[2] = 1.5
    # @show pma[2]
    # @test pma[2] == 1.5
    # pma[2] = 2
    # @show pma[2]
    # @test pma[2] == 2
    # @show pma[3] = 6
    # @show pma[9] = 18
    # @show pma[6] = 2.0
    # @show pma[4] = 10.0


    kv = Dict{Int, Float64}(rand(rng, 1:10000000000) => rand(rng, 1:0.1:10000) for i in 1:1000000)
    keys_array = collect(keys(kv))
    values_array = collect(values(kv))
    @time begin
        pma = create(keys_array, values_array)
    end
    for (k,v) in kv
        if pma[k] != v
            println("k = $k, v =$v, pma[k] = $(pma[k])")
            error("failed")
        end
    end
    println("insert 100000 elements")
    @show pma.capacity
    kv = Dict{Int, Float64}(rand(rng, 1:10000000000) => rand(rng, 1:0.1:10000) for i in 1:100000)
    @time begin 
        insert(pma, kv)
    end
    for (k,v) in kv
        if pma[k] != v
            println("k = $k, v =$v, pma[k] = $(pma[k])")
            error("failed")
        end
    end

    kv = Dict{Int, Float64}(rand(rng, 1:10000000000) => rand(rng, 1:0.1:10000) for i in 1:100000)
    keys_array = collect(keys(kv))
    values_array = collect(values(kv))
    pma = PackedMemoryArray(keys_array, values_array)

    totaltime = @elapsed begin
        k = 1
        while k <= 60
            println("insert 100000 elements")
            @show pma.capacity
            kv = Dict{Int, Float64}(rand(rng, 1:10000000000) => rand(rng, 1:0.1:10000) for i in 1:100000)
            @time begin 
                insert(pma, kv)
            end
            k += 1
        end
    end

    println("Total time = $totaltime")


    return
end

# using Random, BenchmarkTools
# rng = MersenneTwister(1234123)

# function test1()
#     vec = Vector{Union{Nothing,Tuple{Int,Float64}}}(undef, 2097152)
#     return
# end

# function test2()
#     vec = Vector{Tuple{Int,Float64}}(undef, 2097152)
#     return
# end

# vec1 = Vector{Union{Nothing,Tuple{Int,Float64}}}(undef, 2097152)
# vec2 = Vector{Tuple{Int,Float64}}(undef, 2097152)
# vec3 = zeros(Bool, 2097152)
# vec4 = Vector{Tuple{Int,Float64}}(undef, 2097152)
# vec5 = Vector{Tuple{Int, Float64, Bool}}(undef, 2097152)

# function fill_(v1, v2, v3, v4, v5)
#     for i in 1:2097152
#         a = rand(rng, 0:0.1:1)
#         t = (rand(rng, 1:100000000), rand(rng, 1:0.1:10000000))
#         if a >= 0.6
#             v1[i] = t
#             v2[i] = t
#             v3[i] = true
#             v5[i] = (t..., true)
#         else
#             v1[i] = nothing
#             v3[i] = false
#             v5[i] = (0, 0.0, false)
#         end
#         v4[i] = t
#     end
#     return
# end


# function it1(v1)
#     sum = 0.0
#     i = 0
#     @inbounds while i < 2097152
#         i += 1
#         val = v1[i]
#         isnothing(val) && continue
#         sum += val[2]
#     end
#     return sum
# end

# function it2(v2, v3)
#     sum = 0.0
#     @inbounds for i in 1:2097152
#         if v3[i]
#             sum += v2[i][2]
#         end
#     end
#     return sum
# end

# function it3(v2, v3)
#     sum = 0.0
#     @inbounds for i in v2[v3]
#         sum += i[2]
#     end
#     return sum
# end

# function it4(v4)
#     sum = 0.0
#     @inbounds for i in 1:2097152
#         sum += v4[i][2]
#     end
#     return sum
# end

# function it5(v5)
#     sum = 0.0
#     @inbounds for i in 1:2097152
#         k, v, e = v5[i]
#         if e
#             sum += v
#         end
#     end
#     return sum
# end

# # @btime test1()
# # @btime test2()

# fill_(vec1,vec2,vec3, vec4, vec5)

# @btime it1(vec1)
# @btime it2(vec2, vec3)
# @btime it3(vec2, vec3)
# @btime it4(vec4)
# @btime it5(vec5)

main()