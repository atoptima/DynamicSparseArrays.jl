include("iterators.jl")
include("spmv.jl")

function build_params(m::Int, n::Int, nb_keys::Int)
    I = [rand(1:1:m) for _ in 1:nb_keys]
    J = [rand(1:1:n) for _ in 1:nb_keys]
    V = [rand() for _ in 1:nb_keys]
    return I, J, V
end

function print_ranking(title::String, tests::Dict)
    ranking = sort(collect(tests); by = x -> last(x), rev = true)
    printstyled("$title:\n"; color = :green)
    slowest, fastest = ranking
    percentage = ((slowest[2] - fastest[2]) / fastest[2]) * 100
    @printf "\t1. %s - %.2f ns (fastest)\n" fastest[1] fastest[2]
    @printf "\t2. %s - %.2f ns (%.2f%% slower)\n" slowest[1] slowest[2] percentage
end

function performance_tests()
    @testset "Performance tests" begin
        m, n, nb_keys = 1000, 1000, 100
        I, J, V = build_params(m, n, nb_keys)
        dyn_vector = dynamicsparsevec(I, V, m)
        dyn_matrix = dynamicsparse(I, J, V, m, n)
        vector = sparsevec(I, V, m)
        matrix = sparse(I, J, V, m, n)

        # Run a first time to avoid precompilation‡

        vectors_iteration_tests = Dict(
            "Dynamic Sparse Vector" => dynsparsevec_it_perfomance(dyn_vector),
            "Sparse Vector" => sparsevec_it_perfomance(vector)
        )
        matrices_iteration_tests = Dict(
            "Dynamic Sparse Matrix" => dynsparsematrix_it_perfomance(dyn_matrix, I, J),
            "Sparse Matrix" => sparsematrix_it_perfomance(matrix, I, J)
        )
        spmv_tests = Dict(
            "Dynamic Sparse Array" => dynsparsearray_spmv_performance(dyn_matrix, dyn_vector),
            "Sparse Array" => sparsearray_spmv_performance(matrix, vector)
        )
        print_ranking("Vectors Iteration Ranking", vectors_iteration_tests)
        print_ranking("Matrices Iteration Ranking", matrices_iteration_tests)
        print_ranking("SPMV Ranking", spmv_tests)

        #@test vectors_iteration_tests["Dynamic Sparse Vector"] < vectors_iteration_tests["Sparse Vector"]
        #@test matrices_iteration_tests["Sparse Matrix"] < matrices_iteration_tests["Dynamic Sparse Matrix"]
        #@test spmv_tests["Dynamic Sparse Array"] < spmv_tests["Sparse Array"]
    end
end
