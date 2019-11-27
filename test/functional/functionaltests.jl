include("sparsevector.jl")
include("sparsematrix.jl")


function functional_tests()
    # Dynamic Sparse Vector (pma)
    @testset "Instantiation (with multiple elements) in dyn sparse vector" begin
        dynsparsevec_instantiation()
    end
    @testset "Insertions & finds in dyn sparse vector" begin
        dynsparsevec_insertions_and_gets()
    end
    @testset "Deletions in dyn sparse vector" begin
        dynamicsparsevec_deletions()
    end

    # PackedCSC
    @testset "Creation of a PackedCSC matrix" begin
        pcsc_creation()
    end
    @testset "Insertions & finds in PackedCSC matrix" begin
        pcsc_insertions_and_gets()
    end
    @testset "Deletions" begin
        pcsc_deletions()
    end

    # Dynamic Sparse Matrix (MappedPackedCSC)
    @testset "Instantiation (with multiple elements) in MappedPackedCSC matrix" begin
        dynsparsematrix_instantiation()
    end
    @testset "Insertions & finds in MappedPackedCSC matrix" begin
        dynsparsematrix_insertions_and_gets()
    end
end