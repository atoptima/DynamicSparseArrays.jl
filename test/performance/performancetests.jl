include("iterators.jl")
include("spmv.jl")

function build_params(nb_keys::Int = 200, keys_domain::Tuple{Int, Int} = (1, 2000))
    lb, ub = keys_domain
    I = collect(lb:1:ub)
    J = collect(lb:1:ub)
    nb_excluded_keys = (ub-lb)+1-nb_keys
    for _ in 1:nb_excluded_keys
        deleteat!(I, rand(2:1:length(I)-1))
        deleteat!(J, rand(2:1:length(J)-1))
    end
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
    I, J, V = build_params()
    dyn_vector = dynamicsparsevec(I, V)
    dyn_matrix = dynamicsparse(I, J, V)
    vector = sparsevec(I, V)
    matrix = sparse(I, J, V)

    vectors_iteration_tests = Dict(
        "Dynamic Sparse Vector" => dynsparsevec_it_perfomance(dyn_vector),
        "Sparse Vector" => sparsevec_it_perfomance(vector)
    )
    matrices_iteration_tests = Dict(
        "Dynamic Sparse Matrix" => dynsparsematrix_it_perfomance(dyn_matrix, I, J),
        "Sparse Matrix" => sparsematrix_it_perfomance(matrix, I, J)
    )
    spmv_tests = Dict(
        "Dynamic Sparce Array" => dynsparsearray_spmv_performance(dyn_matrix, dyn_vector),
        "Sparce Array" => sparsearray_spmv_performance(matrix, vector)
    )
    print_ranking("Vectors Iteration Ranking", vectors_iteration_tests)
    print_ranking("Matrices Iteration Ranking", matrices_iteration_tests)
    print_ranking("SPMV Ranking", spmv_tests)
end
