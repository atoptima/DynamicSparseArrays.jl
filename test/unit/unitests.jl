include("utils.jl")
include("moves.jl")
include("rebalance.jl")

function unit_tests()

    @testset "Rebalance - unit tests" begin
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
    end

    @testset "Moves - unit tests" begin
        test_movecellstoleft()
        test_movecellstoleft_with_semaphores()
        test_movecellstoright()
        test_movecellstoright_with_semaphores()
    end
    return
end