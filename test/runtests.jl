using DynamicSparseArrays, BenchmarkTools, Test, Printf, Random, SparseArrays, JET

rng = MersenneTwister(1234123)

include("utils.jl")
include("unit/unitests.jl")
include("functional/functionaltests.jl")
include("performance/performancetests.jl")

unit_tests()
functional_tests()
performance_tests()
