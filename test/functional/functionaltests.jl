include("sparsevector.jl")
include("sparsematrix.jl")

function functional_tests()
    # Dynamic Sparse Vector (pma)
    @testset "dynsparsevector (PackedMemoryArray) - func - simple use" begin
        dynsparsevec_simple_use()
    end
    @testset "Insertions & finds in dyn sparse vector" begin
        dynsparsevec_insertions_and_gets()
    end

    # PackedCSC
    @testset "PackedCSC - func - simple use" begin
        pcsc_simple_use()
    end
    
    @testset "Insertions & finds in PackedCSC matrix" begin
        pcsc_insertions_and_gets()
    end
    @testset "Deletions in PackedCSC matrix" begin
        pcsc_deletions()
    end

    # Dynamic Sparse Matrix (MappedPackedCSC)
    @testset "Instantiation (with multiple elements) in MappedPackedCSC matrix" begin
        dynsparsematrix_instantiation()
    end
    @testset "Insertions & finds in MappedPackedCSC matrix" begin
        dynsparsematrix_insertions_and_gets()
    end
    @testset "Deletions in MappedPackedCSC matrix" begin
        dynsparsematrix_deletions()
    end
    return
end