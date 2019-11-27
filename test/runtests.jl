using DynamicSparseArrays, Test, Random

rng = MersenneTwister(1234123)

include("unit/unitests.jl")
include("functional/functionaltests.jl")

unit_tests()
functional_tests()