include("moves.jl")
include("finds.jl")
include("writes.jl")
include("rebalance.jl")
include("comparison.jl")

function unit_tests()
    @testset "Moves - unit tests" begin
        test_movecellstoleft()
        test_movecellstoleft_with_semaphores()
        test_movecellstoright()
        test_movecellstoright_with_semaphores()

        test_pack_spread(100, 10)
        test_pack_spread(1000, 8)
        test_pack_spread(500, 11)
        test_pack_spread(497, 97)
        test_pack_spread(855, 17)
        test_pack_spread(1000000, 5961)

        test_pack_spread_of_empty_array()
        
        test_pack_spread_with_semaphores(100, 10)
        test_pack_spread_with_semaphores(1000, 8)
        test_pack_spread_with_semaphores(500, 11)
        test_pack_spread_with_semaphores(497, 97)
        test_pack_spread_with_semaphores(855, 17)
        test_pack_spread_with_semaphores(1000000, 5961)
    end

    @testset "Finds - unit tests" begin
        test_find()
    end

    @testset "Writes - unit tests" begin
        test_insert()
        test_delete()
    end

    @testset "Comparison - unit tests" begin
        test_equal()
    end
    return
end