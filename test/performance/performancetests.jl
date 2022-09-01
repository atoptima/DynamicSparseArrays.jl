# include("iterators.jl")

# function iterate_over_vector(a)
#     c = 0
#     for f in a
#         if !isnothing(f)
#             @inbounds c += f[2]
#         end
#     end
#     return c
# end

# function iterate_over_matrix(pma)
#     # sum = 0.0
#     # I, J, V = dynsparsematrix_factory(1000, 1000, 0.3) 
#     # matrix = dynamicsparse(I, J, V)
#     c = 0
#     for e in pma
#         #println("\e[31m e = $e \e[00m")
#         #sum += val
#         @inbounds c += e[2]
#     end
#     return c
# end

# function iterate_over_matrix_array(pma)
#     c = 0
#     for e in pma.array
#         if !isnothing(e)
#             @inbounds c += e[2]
#         end
#     end
#     return c
# end

function performance_tests()
#     I, J, V = dynsparsematrix_factory(10000, 10000, 0.3) 
#     matrix = dynamicsparse(I, J, V)
#     pma = matrix[:, 33]

#     @show length(pma.array)

#     vec = Union{Nothing,Tuple{Int,Float64}}[(i,i*1.0) for i in 1:100000]
#     for i in 1:5:5000
#         vec[i] = nothing
#     end

#     vec2 = Vector{Union{Nothing,Tuple{Int,Float64}}}(nothing, 100000)
#     for i in 1:5:5000
#         vec2[i] = (i, i*1.0)
#     end

#     # @time iterate_over_vector(vec)
#     # @time iterate_over_vector(vec2)
#     println("------------")
#     @time iterate_over_matrix(pma)
#     @time iterate_over_matrix_array(pma)
#     @time iterate_over_vector(pma.array)

#     println("**********************")

#     @time iterate_over_matrix(pma)
#     @time iterate_over_matrix_array(pma)
#     @time iterate_over_vector(pma.array)

#     println("-------------- mem check ------------")
#     vec = [1,2,3]
#     vec = ["a", "v", "d"]
#     @show p = pointer(vec)
#     @show unsafe_load(p, 1)
#     @show unsafe_load(p, 2)

#     @show p2 = pointer(pma.array)
#     @show unsafe_load(p2, 1)
#     @show unsafe_load(p2, 2)
end